# vim: set ts=4 sw=4 et:

update_check() {
    local i p url sfname lpname bbname githubname rx found_version consider

    if ! type curl >/dev/null 2>&1; then
        echo "ERROR: cannot find \`curl' executable!"
        return 1
    fi

    export LC_ALL=C
    : ${update_pkgname:=$pkgname}

    if [ -z "$update_site" ]; then
        printf '%s\n' "$homepage"
        for i in $distfiles; do
            printf '%s\n' "${i%/*}/"
        done
    else
        printf '%s\n' "$update_site"
    fi |
    while IFS= read -r url; do
        rx=
        if [ -z "$update_site" ]; then
            case "$url" in
            *sourceforge.net/sourceforge*)
                sfname="$(printf %s "$url" | cut -d/ -f5)"
                url="http://sourceforge.net/projects/$sfname/rss?limit=200";;
            *code.google.com*|*googlecode*)
                url="http://code.google.com/p/$update_pkgname/downloads/list";;
            *launchpad.net*)
                lpname="$(printf %s "$url" | cut -d/ -f4)"
                url="https://launchpad.net/$lpname/+download";;
            *cpan.*)
                update_pkgname=${update_pkgname#perl-};;
            *pypi.python.org*)
                update_pkgname=${update_pkgname#python-};;
            *github.com*)
                githubname="$(printf %s "$url" | cut -d/ -f4,5)"
                url="https://github.com/$githubname/tags"
                rx='/archive/(v?|\Q'"$update_pkgname"'\E-)?\K[\d\.]+(?=\.tar\.gz")';;
            *bitbucket.org*)
                bbname="$(printf %s "$url" | cut -d/ -f4,5)"
                url="https://bitbucket.org/$bbname/downloads"
                rx='/(get|downloads)/(v?|\Q'"$update_pkgname"'\E-)?\K[\d\.]+(?=\.tar\.gz")';;
            *ftp.gnome.org*)
                : ${update_pattern="$update_pkgname-\K[0-9]\.[0-9]*[02468]\.[0-9.]*[0-9](?=)"}
                url="http://ftp.gnome.org/pub/GNOME/sources/$update_pkgname/cache.json";;
            *kernel.org/pub/linux/kernel/*)
                rx=linux-'\K'${version%.*}'[\d.]+(?=\.tar\.xz)';;
            esac
        fi

        rx=${update_pattern:-$rx}
        rx=${rx:-'(?<!-)\b\Q'"$update_pkgname"'\E[-_]?((src|source)[-_])?\K([^-/_\s]*?\d[^-/_\s]*?)(?=(?:[-_.](?:src|source|orig))?\.(?:[jt]ar|shar|t[bglx]z|tbz2|zip))\b'}

        if [ -n "$XBPS_UPDATE_CHECK_VERBOSE" ]; then
            echo "fetching $url" 1>&2
        fi
        curl -A "xbps-src-update-check/$XBPS_SRC_VERSION" --max-time 10 -Lsk "$url" |
            grep -Po -i "$rx"
    done |
    sort -Vu |
    { 
        grep . || echo "NO VERSION found for $pkgname" 1>&2
    } |
    while IFS= read -r found_version; do
        if [ -n "$XBPS_UPDATE_CHECK_VERBOSE" ]; then
            echo "found version $found_version"
        fi
        consider=true
        p="$update_ignore "
        while [ -n "$p" ]; do
            i=${p%% *}
            p=${p#* }
            case "$found_version" in
            $i)
                consider=false
                if [ -n "$XBPS_UPDATE_CHECK_VERBOSE" ]; then
                    echo "ignored $found_version due to $i"
                fi
            esac
        done
        if $consider; then
            xbps-uhelper cmpver "$pkgname-${update_version:-$version}_1" \
                "$pkgname-$(printf %s "$found_version" | tr - .)_1"
            if [ $? = 255 ]; then
                echo "${pkgname}-${version} -> ${pkgname}-${found_version}"
            fi
        fi
    done
}
