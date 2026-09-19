# Maintainer: nullstacked
pkgname=kvmd-paste-clipboard
pkgver=1.0.1
pkgrel=1
pkgdesc="Floating paste-from-clipboard button for PiKVM Web UI"
arch=('any')
url="https://github.com/nullstacked/kvmd-paste-clipboard"
license=('GPL3')
depends=('kvmd')
install=kvmd-paste-clipboard.install

package() {
    install -Dm644 "$srcdir/../files/apply-patches.sh" "$pkgdir/usr/share/kvmd-paste-clipboard/apply-patches.sh"
    chmod +x "$pkgdir/usr/share/kvmd-paste-clipboard/apply-patches.sh"
    install -Dm644 "$srcdir/../files/paste-clipboard.css" "$pkgdir/usr/share/kvmd-paste-clipboard/paste-clipboard.css"
    install -Dm644 "$srcdir/../kvmd-paste-clipboard.hook" "$pkgdir/etc/pacman.d/hooks/kvmd-paste-clipboard.hook"
}
