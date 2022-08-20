# This builds the files needed to run Diogenes.

# Note that the dictionaries and morphological data are built using
# different makefiles; read README.md for details.

include mk.common

GITHUBTOKEN=replace-this-token
CLOUDFRONTID=replace-this-id

DIOGENESVERSION = $(shell grep "Diogenes::Base::Version" server/Diogenes/Base.pm | sed -n 's/[^"]*"\([^"]*\)"[^"]*/\1/p')

ELECTRONVERSION = 20.0.0
ENTSUM = 84cb3710463ea1bd80e6db3cf31efcb19345429a3bafbefc9ecff71d0a64c21c
UNICODEVERSION = 7.0.0
UNICODESUM = bfa3da58ea982199829e1107ac5a9a544b83100470a2d0cc28fb50ec234cb840
STRAWBERRYPERLVERSION=5.28.0.1

all: server/Diogenes/unicode-equivs.pl server/Diogenes/EntityTable.pm server/fonts/GentiumPlus-I.woff server/fonts/GentiumPlus-R.woff client/node-font-list/package.json

client/node-font-list/package.json:
	rm -rf client/node-font-list
	cd client && git clone https://github.com/oldj/node-font-list.git

$(DEPDIR)/UnicodeData-$(UNICODEVERSION).txt:
	curl -o $@ http://www.unicode.org/Public/$(UNICODEVERSION)/ucd/UnicodeData.txt
	printf '%s  %s\n' $(UNICODESUM) $@ | shasum -c -a 256

server/Diogenes/unicode-equivs.pl: utils/make_unicode_compounds.pl $(DEPDIR)/UnicodeData-$(UNICODEVERSION).txt
	./utils/make_unicode_compounds.pl < $(DEPDIR)/UnicodeData-$(UNICODEVERSION).txt > $@

build/GentiumPlus-5.000-web.zip:
	mkdir -p build
	curl -o $@ https://software.sil.org/downloads/r/gentium/GentiumPlus-5.000-web.zip

server/fonts/GentiumPlus-I.woff: build/GentiumPlus-5.000-web.zip
	unzip -n build/GentiumPlus-5.000-web.zip -d build
	mkdir -p server/fonts
	cp build/GentiumPlus-5.000-web/web/GentiumPlus-I.woff $@

server/fonts/GentiumPlus-R.woff: build/GentiumPlus-5.000-web.zip
	unzip -n build/GentiumPlus-5.000-web.zip -d build
	mkdir -p server/fonts
	cp build/GentiumPlus-5.000-web/web/GentiumPlus-R.woff $@

$(DEPDIR)/PersXML.ent:
	curl -o $@ http://www.perseus.tufts.edu/DTD/1.0/PersXML.ent
	printf '%s  %s\n' $(ENTSUM) $@ | shasum -c -a 256

server/Diogenes/EntityTable.pm: utils/ent_to_array.pl $(DEPDIR)/PersXML.ent
	printf '# Generated by makefile using utils/ent_to_array.pl\n' > $@
	printf 'package Diogenes::EntityTable;\n\n' >> $@
	./utils/ent_to_array.pl < $(DEPDIR)/PersXML.ent >> $@

electron/electron-v$(ELECTRONVERSION)-linux-x64:
	mkdir -p electron
	curl -L https://github.com/electron/electron/releases/download/v$(ELECTRONVERSION)/electron-v$(ELECTRONVERSION)-linux-x64.zip > electron/electron-v$(ELECTRONVERSION)-linux-x64.zip
	unzip -d electron/electron-v$(ELECTRONVERSION)-linux-x64 electron/electron-v$(ELECTRONVERSION)-linux-x64.zip
	rm electron/electron-v$(ELECTRONVERSION)-linux-x64.zip

linux64: all electron/electron-v$(ELECTRONVERSION)-linux-x64
	rm -rf app/linux64
	mkdir -p app/linux64
	cp -r electron/electron-v$(ELECTRONVERSION)-linux-x64/* app/linux64
	cp -r server app/linux64
	cp -r dependencies app/linux64
	cp -r dist app/linux64
	cp -r client app/linux64/resources/app
	echo '{ "version": "'$(DIOGENESVERSION)'" } ' > app/linux64/resources/app/version.js
	mv app/linux64/electron app/linux64/diogenes
	cp COPYING README.md app/linux64

electron/electron-v$(ELECTRONVERSION)-win32-ia32:
	mkdir -p electron
	curl -L https://github.com/electron/electron/releases/download/v$(ELECTRONVERSION)/electron-v$(ELECTRONVERSION)-win32-ia32.zip > electron/electron-v$(ELECTRONVERSION)-win32-ia32.zip
	unzip -d electron/electron-v$(ELECTRONVERSION)-win32-ia32 electron/electron-v$(ELECTRONVERSION)-win32-ia32.zip
	rm electron/electron-v$(ELECTRONVERSION)-win32-ia32.zip

electron/electron-v$(ELECTRONVERSION)-win32-x64:
	mkdir -p electron
	curl -L https://github.com/electron/electron/releases/download/v$(ELECTRONVERSION)/electron-v$(ELECTRONVERSION)-win32-x64.zip > electron/electron-v$(ELECTRONVERSION)-win32-x64.zip
	unzip -d electron/electron-v$(ELECTRONVERSION)-win32-x64 electron/electron-v$(ELECTRONVERSION)-win32-x64.zip
	rm electron/electron-v$(ELECTRONVERSION)-win32-x64.zip

build/w32perl:
	mkdir -p build/w32perl/strawberry
	curl -L http://strawberryperl.com/download/$(STRAWBERRYPERLVERSION)/strawberry-perl-$(STRAWBERRYPERLVERSION)-32bit-portable.zip > build/w32perl/strawberry-perl-$(STRAWBERRYPERLVERSION)-32bit-portable.zip
	unzip -d build/w32perl/strawberry build/w32perl/strawberry-perl-$(STRAWBERRYPERLVERSION)-32bit-portable.zip
	rm build/w32perl/strawberry-perl-$(STRAWBERRYPERLVERSION)-32bit-portable.zip

build/w64perl:
	mkdir -p build/w64perl/strawberry
	curl -L http://strawberryperl.com/download/$(STRAWBERRYPERLVERSION)/strawberry-perl-$(STRAWBERRYPERLVERSION)-64bit-portable.zip > build/w64perl/strawberry-perl-$(STRAWBERRYPERLVERSION)-64bit-portable.zip
	unzip -d build/w64perl/strawberry build/w64perl/strawberry-perl-$(STRAWBERRYPERLVERSION)-64bit-portable.zip
	rm build/w64perl/strawberry-perl-$(STRAWBERRYPERLVERSION)-64bit-portable.zip

build/rcedit.exe:
	mkdir -p build
	curl -Lo build/rcedit.exe https://github.com/electron/rcedit/releases/download/v0.1.0/rcedit.exe

build/icons/256.png build/icons/128.png build/icons/64.png build/icons/48.png build/icons/32.png build/icons/16.png: dist/icon.svg
	@echo "Rendering icons (needs rsvg-convert and Adobe Garamond Pro font)"
	mkdir -p build/icons
	rsvg-convert -w 256 -h 256 dist/icon.svg > build/icons/256.png
	rsvg-convert -w 128 -h 128 dist/icon.svg > build/icons/128.png
	rsvg-convert -w 64 -h 64 dist/icon.svg > build/icons/64.png
	rsvg-convert -w 48 -h 48 dist/icon.svg > build/icons/48.png
	rsvg-convert -w 32 -h 32 dist/icon.svg > build/icons/32.png
	rsvg-convert -w 16 -h 16 dist/icon.svg > build/icons/16.png

build/icons/diogenes.ico: build/icons/256.png build/icons/128.png build/icons/64.png build/icons/48.png build/icons/32.png build/icons/16.png
	icotool -c build/icons/256.png build/icons/128.png build/icons/64.png build/icons/48.png build/icons/32.png build/icons/16.png > $@
	cp build/icons/diogenes.ico server/favicon.ico

build/diogenes.icns: build/icons/256.png build/icons/128.png build/icons/64.png build/icons/48.png build/icons/32.png build/icons/16.png
	png2icns $@ build/icons/256.png build/icons/128.png build/icons/48.png build/icons/32.png build/icons/16.png

w32: all electron/electron-v$(ELECTRONVERSION)-win32-ia32 build/w32perl build/icons/diogenes.ico build/rcedit.exe
	@echo "Making windows package. Note that this requires wine to be"
	@echo "installed, to edit the .exe resources."
	rm -rf app/w32
	mkdir -p app/w32
	cp -r electron/electron-v$(ELECTRONVERSION)-win32-ia32/* app/w32
	cp -r client app/w32/resources/app
	echo '{ "version": "'$(DIOGENESVERSION)'" } ' > app/w32/resources/app/version.js
	mv app/w32/electron.exe app/w32/diogenes.exe
	cp -r server app/w32
	cp -r dependencies app/w32
	cp -r build/w32perl/strawberry app/w32
	cp build/icons/diogenes.ico app/w32
	cp COPYING app/w32/COPYING.txt
	cp README.md app/w32/README.md
	wine64 build/rcedit.exe app/w32/diogenes.exe \
	    --set-icon build/icons/diogenes.ico \
	    --set-product-version $(DIOGENESVERSION) \
	    --set-file-version $(DIOGENESVERSION) \
	    --set-version-string CompanyName "Classics Dept. Durham Univ." \
	    --set-version-string ProductName Diogenes \
	    --set-version-string FileDescription Diogenes

w64: all electron/electron-v$(ELECTRONVERSION)-win32-x64 build/w64perl build/icons/diogenes.ico build/rcedit.exe
	@echo "Making windows package. Note that this requires wine to be"
	@echo "installed, to edit the .exe resources."
	rm -rf app/w64
	mkdir -p app/w64
	cp -r electron/electron-v$(ELECTRONVERSION)-win32-x64/* app/w64
	cp -r client app/w64/resources/app
	echo '{ "version": "'$(DIOGENESVERSION)'" } ' > app/w64/resources/app/version.js
	mv app/w64/electron.exe app/w64/diogenes.exe
	cp -r server app/w64
	cp -r dependencies app/w64
	cp -r build/w64perl/strawberry app/w64
	cp build/icons/diogenes.ico app/w64
	cp COPYING app/w64/COPYING.txt
	cp README.md app/w64/README.md
	wine64 build/rcedit.exe app/w64/diogenes.exe \
	    --set-icon build/icons/diogenes.ico \
	    --set-product-version $(DIOGENESVERSION) \
	    --set-file-version $(DIOGENESVERSION) \
	    --set-version-string CompanyName "Classics Dept. Durham Univ." \
	    --set-version-string ProductName Diogenes \
	    --set-version-string FileDescription Diogenes

electron/electron-v$(ELECTRONVERSION)-darwin-x64:
	mkdir -p electron
	curl -L https://github.com/electron/electron/releases/download/v$(ELECTRONVERSION)/electron-v$(ELECTRONVERSION)-darwin-x64.zip > electron/electron-v$(ELECTRONVERSION)-darwin-x64.zip
	unzip -d electron/electron-v$(ELECTRONVERSION)-darwin-x64 electron/electron-v$(ELECTRONVERSION)-darwin-x64.zip
	rm electron/electron-v$(ELECTRONVERSION)-darwin-x64.zip

electron/electron-v$(ELECTRONVERSION)-darwin-arm64:
	mkdir -p electron
	curl -L https://github.com/electron/electron/releases/download/v$(ELECTRONVERSION)/electron-v$(ELECTRONVERSION)-darwin-arm64.zip > electron/electron-v$(ELECTRONVERSION)-darwin-arm64.zip
	unzip -d electron/electron-v$(ELECTRONVERSION)-darwin-arm64 electron/electron-v$(ELECTRONVERSION)-darwin-arm64.zip
	rm electron/electron-v$(ELECTRONVERSION)-darwin-arm64.zip
	# Remove spurious "Electron is damaged" error message
	xattr -cr electron/electron-v$(ELECTRONVERSION)-darwin-arm64/Electron.app

mac-x64: all electron/electron-v$(ELECTRONVERSION)-darwin-x64 build/diogenes.icns
	rm -rf app/mac-x64
	mkdir -p app/mac-x64
	mkdir -p app/mac-x64/about
	cp -r electron/electron-v$(ELECTRONVERSION)-darwin-x64/* app/mac-x64
	cp -r client app/mac-x64/Electron.app/Contents/Resources/app
	echo '{ "version": "'$(DIOGENESVERSION)'" } ' > app/mac-x64/Electron.app/Contents/Resources/app/version.js
	cp -r server app/mac-x64/Electron.app/Contents
	cp -r dependencies app/mac-x64/Electron.app/Contents
	cp build/diogenes.icns app/mac-x64/Electron.app/Contents/Resources/
	perl -pi -e 's/electron.icns/diogenes.icns/g' app/mac-x64/Electron.app/Contents/Info.plist
	perl -pi -e 's/Electron/Diogenes/g' app/mac-x64/Electron.app/Contents/Info.plist
	perl -pi -e 's/com.github.electron/uk.ac.durham.diogenes/g' app/mac-x64/Electron.app/Contents/Info.plist
	perl -pi -e 's/$(ELECTRONVERSION)/$(DIOGENESVERSION)/g' app/mac-x64/Electron.app/Contents/Info.plist
	perl -pi -e 's#</dict>#<key>NSHumanReadableCopyright</key>\n<string>Copyright © 2019 Peter Heslin\nDistributed under the GNU GPL version 3</string>\n</dict>#' app/mac-x64/Electron.app/Contents/Info.plist
	mv app/mac-x64/Electron.app app/mac-x64/Diogenes.app
	mv app/mac-x64/Diogenes.app/Contents/MacOS/Electron app/mac-x64/Diogenes.app/Contents/MacOS/Diogenes
	# There are now multiple helper apps, and each has an Info.plist that
	# may need modifying, so for now we just refrain from renaming
	# mv "app/mac-x64/Diogenes.app/Contents/Frameworks/Electron Helper.app/Contents/MacOS/Electron Helper" "app/mac-x64/Diogenes.app/Contents/Frameworks/Electron Helper.app/Contents/MacOS/Diogenes Helper"
	# mv "app/mac-x64/Diogenes.app/Contents/Frameworks/Electron Helper.app" "app/mac-x64/Diogenes.app/Contents/Frameworks/Diogenes Helper.app"
	cp COPYING app/mac-x64/about/COPYING.txt
	cp README.md app/mac-x64/about/README.md
	mv app/mac-x64/LICENSE app/mac-x64/about/
	mv app/mac-x64/LICENSES.chromium.html app/mac-x64/about/
	mv app/mac-x64/version app/mac-x64/about/

mac-arm64: all electron/electron-v$(ELECTRONVERSION)-darwin-arm64 build/diogenes.icns
	rm -rf app/mac-arm64
	mkdir -p app/mac-arm64
	mkdir -p app/mac-arm64/about
	cp -r electron/electron-v$(ELECTRONVERSION)-darwin-arm64/* app/mac-arm64
	cp -r client app/mac-arm64/Electron.app/Contents/Resources/app
	echo '{ "version": "'$(DIOGENESVERSION)'" } ' > app/mac-arm64/Electron.app/Contents/Resources/app/version.js
	cp -r server app/mac-arm64/Electron.app/Contents
	cp -r dependencies app/mac-arm64/Electron.app/Contents
	cp build/diogenes.icns app/mac-arm64/Electron.app/Contents/Resources/
	perl -pi -e 's/electron.icns/diogenes.icns/g' app/mac-arm64/Electron.app/Contents/Info.plist
	perl -pi -e 's/Electron/Diogenes/g' app/mac-arm64/Electron.app/Contents/Info.plist
	perl -pi -e 's/com.github.electron/uk.ac.durham.diogenes/g' app/mac-arm64/Electron.app/Contents/Info.plist
	perl -pi -e 's/$(ELECTRONVERSION)/$(DIOGENESVERSION)/g' app/mac-arm64/Electron.app/Contents/Info.plist
	perl -pi -e 's#</dict>#<key>NSHumanReadableCopyright</key>\n<string>Copyright © 2019 Peter Heslin\nDistributed under the GNU GPL version 3</string>\n</dict>#' app/mac-arm64/Electron.app/Contents/Info.plist
	mv app/mac-arm64/Electron.app app/mac-arm64/Diogenes.app
	mv app/mac-arm64/Diogenes.app/Contents/MacOS/Electron app/mac-arm64/Diogenes.app/Contents/MacOS/Diogenes
	# mv "app/mac-arm64/Diogenes.app/Contents/Frameworks/Electron Helper.app/Contents/MacOS/Electron Helper" "app/mac-arm64/Diogenes.app/Contents/Frameworks/Electron Helper.app/Contents/MacOS/Diogenes Helper"
	# mv "app/mac-arm64/Diogenes.app/Contents/Frameworks/Electron Helper.app" "app/mac-arm64/Diogenes.app/Contents/Frameworks/Diogenes Helper.app"
	cp COPYING app/mac-arm64/about/COPYING.txt
	cp README.md app/mac-arm64/about/README.md
	mv app/mac-arm64/LICENSE app/mac-arm64/about/
	mv app/mac-arm64/LICENSES.chromium.html app/mac-arm64/about/
	mv app/mac-arm64/version app/mac-arm64/about/


zip-linux64: app/linux64
	rm -rf app/diogenes-linux-$(DIOGENESVERSION)
	mv app/linux64 app/diogenes-linux-$(DIOGENESVERSION)
	cd app;tar c diogenes-linux-$(DIOGENESVERSION) | xz > diogenes-linux-$(DIOGENESVERSION).tar.xz
	rm -rf app/diogenes-linux-$(DIOGENESVERSION)

apps: mac w32 linux64

zip-mac: app/mac
	rm -rf app/diogenes-mac-$(DIOGENESVERSION)
	mv app/mac app/diogenes-mac-$(DIOGENESVERSION)
	cd app;zip -r diogenes-mac-$(DIOGENESVERSION).zip diogenes-mac-$(DIOGENESVERSION)
	rm -rf diogenes-mac-$(DIOGENESVERSION)

zip-w32: app/w32
	rm -rf app/diogenes-win32-$(DIOGENESVERSION)
	mv app/w32 app/diogenes-win32-$(DIOGENESVERSION)
	cd app;zip -r diogenes-win32-$(DIOGENESVERSION).zip diogenes-win32-$(DIOGENESVERSION)
	rm -rf app/diogenes-win32-$(DIOGENESVERSION)

zip-w64: app/w64
	rm -rf app/diogenes-win64-$(DIOGENESVERSION)
	mv app/w64 app/diogenes-win64-$(DIOGENESVERSION)
	cd app;zip -r diogenes-win64-$(DIOGENESVERSION).zip diogenes-win64-$(DIOGENESVERSION)
	rm -rf app/diogenes-win64-$(DIOGENESVERSION)

zip-all: zip-linux64 zip-mac zip-w32 zip-w64

build/inno-setup/app/ISCC.exe:
	mkdir -p build/inno-setup
	curl -Lo build/inno-setup/is.exe http://www.jrsoftware.org/download.php/is.exe
	cd build/inno-setup; innoextract is.exe

# OS X after Catalina will not run 32-bit apps, even under emulation.
# This is not a problem with rcedit, as we can use 64-bit wine to run
# a 64-bit rcedit.  But there is currently only a 32-bit version of
# Inno Setup available, so we use Docker (which is slower) instead;
# this solution is from
# https://gist.github.com/amake/3e7194e5e61d0e1850bba144797fd797
installer-w32: install/diogenes-setup-win32-$(DIOGENESVERSION).exe
#install/diogenes-setup-win32-$(DIOGENESVERSION).exe: build/inno-setup/app/ISCC.exe app/w32
install/diogenes-setup-win32-$(DIOGENESVERSION).exe: app/w32
	mkdir -p install
	rm -f install/diogenes-setup-win32-$(DIOGENESVERSION).exe
# wine64 build/inno-setup/app/ISCC.exe dist/diogenes-win32.iss
	docker run --rm -i -v "$(PWD):/work" amake/innosetup dist/diogenes-win32.iss
	mv -f dist/Output/mysetup.exe install/diogenes-setup-win32-$(DIOGENESVERSION).exe
	rmdir dist/Output

installer-w64: install/diogenes-setup-win64-$(DIOGENESVERSION).exe
install/diogenes-setup-win64-$(DIOGENESVERSION).exe: build/inno-setup/app/ISCC.exe app/w64
	mkdir -p install
	rm -f install/diogenes-setup-win64-$(DIOGENESVERSION).exe
# wine64 build/inno-setup/app/ISCC.exe dist/diogenes-win64.iss
	docker run --rm -i -v "$(PWD):/work" amake/innosetup dist/diogenes-win64.iss
	mv -f dist/Output/mysetup.exe install/diogenes-setup-win64-$(DIOGENESVERSION).exe
	rmdir dist/Output

# Experience shows that the pkg installer is fragile, so we have
# reverted to distributing the app as a simple zip file, which is less
# potentially confusing than a DMG installer.
installer-mac: install/diogenes-mac-$(DIOGENESVERSION).zip
install/diogenes-mac-$(DIOGENESVERSION).zip: app/mac
	mkdir -p install
	rm -f install/diogenes-mac-$(DIOGENESVERSION).zip
	cd app/mac; zip -r diogenes-mac-$(DIOGENESVERSION).zip Diogenes.app about
	mv app/mac/diogenes-mac-$(DIOGENESVERSION).zip install/

# NB. Installing this Mac package will report success but silently
# fail if there exists another copy of Diogenes.app with the same
# version number anywhere whatsoever on the same disk volume, such as
# in the mac directory here or another random copy on the devel
# machine.  In other words, this installer usually will fail silently
# when run on the machine that created the installer.
installer-macpkg: install/diogenes-mac-$(DIOGENESVERSION).pkg
install/diogenes-mac-$(DIOGENESVERSION).pkg: app/mac
	mkdir -p install
	rm -f install/diogenes-mac-$(DIOGENESVERSION).pkg
	fpm --prefix=/Applications -C app/mac -t osxpkg -n Diogenes -v $(DIOGENESVERSION) --osxpkg-identifier-prefix uk.ac.durham.diogenes -s dir Diogenes.app
	mv Diogenes-$(DIOGENESVERSION).pkg install/diogenes-mac-$(DIOGENESVERSION).pkg

# Add --verbose to fpm call to diagnose any errors

installer-deb64: install/diogenes-$(DIOGENESVERSION)_amd64.deb
install/diogenes-$(DIOGENESVERSION)_amd64.deb: app/linux64
	mkdir -p install
	rm -f install/diogenes-$(DIOGENESVERSION)_amd64.deb
	fpm -s dir -t deb -n diogenes -v $(DIOGENESVERSION) -a x86_64 \
		-p diogenes-$(DIOGENESVERSION)_amd64.deb -d perl \
		-m p.j.heslin@durham.ac.uk --vendor p.j.heslin@durham.ac.uk \
		--url https://d.iogen.es/d \
		--description "Tool for legacy databases of Latin and Greek texts" \
		--license GPL3 --post-install dist/post-install-deb.sh \
		app/linux64/=/usr/local/diogenes/ \
		dist/diogenes.desktop=/usr/share/applications/ \
		dist/icon.svg=/usr/share/icons/diogenes.svg
	mv diogenes-$(DIOGENESVERSION)_amd64.deb install/diogenes-$(DIOGENESVERSION)_amd64.deb

# Dependency on libXScrnSaver in Fedora should be a transient bug; see:
# https://github.com/atom/atom/issues/13176
installer-rpm64: install/diogenes-$(DIOGENESVERSION).x86_64.rpm
install/diogenes-$(DIOGENESVERSION).x86_64.rpm: app/linux64
	mkdir -p install
	rm -f install/diogenes-$(DIOGENESVERSION).x86_64.rpm
	fpm -s dir -t rpm --rpm-os linux --architecture all -n diogenes \
                -v $(DIOGENESVERSION) -a x86_64 \
		-p diogenes-$(DIOGENESVERSION).x86_64.rpm -d perl \
                -d libXScrnSaver \
		-m p.j.heslin@durham.ac.uk --vendor p.j.heslin@durham.ac.uk \
		--url https://d.iogen.es/d \
		--description "Tool for legacy databases of Latin and Greek texts" \
		--license GPL3 --post-install dist/post-install-rpm.sh \
		app/linux64/=/usr/local/diogenes/ \
		dist/diogenes.desktop=/usr/share/applications/ \
		dist/icon.svg=/usr/share/icons/diogenes.svg
	mv diogenes-$(DIOGENESVERSION).x86_64.rpm install/diogenes-$(DIOGENESVERSION).x86_64.rpm

installer-arch64: install/diogenes-$(DIOGENESVERSION).pkg.tar.xz
install/diogenes-$(DIOGENESVERSION).pkg.tar.xz: app/linux64
	mkdir -p install
	rm -f install/diogenes-$(DIOGENESVERSION).pkg.tar.xz
	fpm -s dir -t pacman -n diogenes -v $(DIOGENESVERSION) -a x86_64 \
		-p diogenes-$(DIOGENESVERSION).pkg.tar.xz -d perl \
		-m p.j.heslin@durham.ac.uk --vendor p.j.heslin@durham.ac.uk \
		--url https://d.iogen.es/d \
		--description "Tool for legacy databases of Latin and Greek texts" \
		--license GPL3 --post-install dist/post-install-rpm.sh \
		app/linux64/=/usr/local/diogenes/ \
		dist/diogenes.desktop=/usr/share/applications/ \
		dist/icon.svg=/usr/share/icons/diogenes.svg
	mv diogenes-$(DIOGENESVERSION).pkg.tar.xz install/diogenes-$(DIOGENESVERSION).pkg.tar.xz

# For now, we stick with the 32-bit app for Windows

# installer-all: installer-w32 installer-w64 installer-mac installer-deb64 installer-rpm64 installer-arch64
installer-all: installer-w32 installer-mac installer-deb64 installer-rpm64 installer-arch64
# installers = install/diogenes-setup-win32-$(DIOGENESVERSION).exe install/diogenes-setup-win64-$(DIOGENESVERSION).exe install/diogenes-mac-$(DIOGENESVERSION).zip install/diogenes-$(DIOGENESVERSION)_amd64.deb install/diogenes-$(DIOGENESVERSION).x86_64.rpm install/diogenes-$(DIOGENESVERSION).pkg.tar.xz
installers = install/diogenes-setup-win32-$(DIOGENESVERSION).exe install/diogenes-mac-$(DIOGENESVERSION).zip install/diogenes-$(DIOGENESVERSION)_amd64.deb install/diogenes-$(DIOGENESVERSION).x86_64.rpm install/diogenes-$(DIOGENESVERSION).pkg.tar.xz

clean:
	rm -f $(DEPDIR)/UnicodeData-$(UNICODEVERSION).txt
	rm -f server/Diogenes/unicode-equivs.pl
	rm -f $(DEPDIR)/PersXML.ent
	rm -f server/Diogenes/EntityTable.pm
	rm -rf server/fonts
	rm -rf build
	rm -rf electron
	rm -rf app
	rm -rf install


# These targets will not be of interest to anyone else

# make release GITHUBTOKEN=github-access-token
# release: $(installers)
release:
	git tag -a -m "Diogenes Public Release" $(DIOGENESVERSION)
	git push origin master
	utils/github-create-release.sh github_api_token=$(GITHUBTOKEN) owner=pjheslin repo=diogenes tag=$(DIOGENESVERSION) prerelease=false
	for installer in $(installers); do utils/upload-github-release-asset.sh github_api_token=$(GITHUBTOKEN) owner=pjheslin repo=diogenes tag=$(DIOGENESVERSION) filename=$$installer > /dev/null; done

# make update-website CLOUDFRONTID=id
update-website:
	echo 'var DiogenesVersion = "'$(DIOGENESVERSION)'";' > ../../website/d/version.js
	rclone -v copy ../../website/d/version.js diogenes-s3:d.iogen.es/d/
	aws cloudfront create-invalidation --distribution-id $(CLOUDFRONTID) --paths '/*'

# For DiogenesWeb
morph-deploy:
	docker build -t pjheslin/diogenesmorph .
	docker push pjheslin/diogenesmorph
	eb deploy

# If data has changed, update prebuilt data
prebuilt: prebuilt-data.tar.xz
	mv prebuilt-data.tar.xz ../diogenes-prebuilt-data/
	cd ../diogenes-prebuilt-data; git add prebuilt-data.tar.xz; git commit -m "Update to prebuilt data"; git push

prebuilt-data.tar.xz:
	tar -cvf prebuilt-data.tar $(DATA)
	xz prebuilt-data.tar

