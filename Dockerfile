FROM alpine:3.18.5 as build
ARG BUILD

ARG LUAJIT_INC=/usr/include/luajit-2.1
ARG LUAJIT_LIB=/usr/lib
ARG NGINX_VER=1.25.2

WORKDIR /src
# Requirements
RUN apk add --no-cache ca-certificates build-base patch cmake git mercurial libtool autoconf automake \
    libatomic_ops-dev zlib-dev luajit-dev pcre-dev linux-headers yajl-dev libxml2-dev libxslt-dev perl-dev lua5.1-dev

# Nginx
RUN wget https://nginx.org/download/nginx-"$NGINX_VER".tar.gz -O - | tar xzC /src && \
    mv /src/nginx-"$NGINX_VER" /src/nginx && \
    cd /src/nginx && \
    sed -i "s/OPTIMIZE[ \\t]*=>[ \\t]*'-O'/OPTIMIZE          => '-O3'/g" src/http/modules/perl/Makefile.PL && \
    sed -i 's/NGX_PERL_CFLAGS="$CFLAGS `$NGX_PERL -MExtUtils::Embed -e ccopts`"/NGX_PERL_CFLAGS="`$NGX_PERL -MExtUtils::Embed -e ccopts` $CFLAGS"/g' auto/lib/perl/conf && \
    sed -i 's/NGX_PM_CFLAGS=`$NGX_PERL -MExtUtils::Embed -e ccopts`/NGX_PM_CFLAGS="`$NGX_PERL -MExtUtils::Embed -e ccopts` $CFLAGS"/g' auto/lib/perl/conf && \
    # modules
    git clone --recursive https://github.com/google/ngx_brotli /src/ngx_brotli && \
    git clone --recursive https://github.com/nginx/njs /src/njs && \
    git clone --recursive https://github.com/openresty/lua-nginx-module /src/lua-nginx-module && \
    git clone --recursive https://github.com/openresty/lua-resty-core /src/lua-resty-core && \
    git clone --recursive https://github.com/openresty/lua-resty-lrucache /src/lua-resty-lrucache && \
    git clone --recursive https://github.com/quictls/openssl --branch openssl-3.1.2+quic /src/openssl

# Configure
RUN cd /src/nginx && \
    /src/nginx/configure \
    --build=${BUILD} \
    --with-compat \
    --with-threads \
    --with-file-aio \
    --with-libatomic \
    --with-pcre \
    --with-pcre-jit \
    --without-poll_module \
    --without-select_module \
    --with-openssl="/src/openssl" \
    --with-ld-opt="-L/src/openssl/build/lib" \
    --with-cc-opt="-I/src/openssl/build/include" \
    --with-openssl-opt=no-weak-ssl-ciphers \
    --with-openssl-opt=no-ssl2 \    
    --with-openssl-opt=no-ssl3 \    
    --with-stream \
#    --with-stream_ssl_module \
#    --with-stream_realip_module \
#    --with-stream_ssl_preread_module \
    --with-http_v2_module \
#    --with-http_v2_hpack_enc \
    --with-http_v3_module \
    --with-http_ssl_module \
    --with-http_perl_module \
    --with-http_realip_module \
    --with-http_gunzip_module \
    --with-http_addition_module \
    --with-http_gzip_static_module \
    --with-http_auth_request_module \
    --add-module=/src/ngx_brotli \
    --add-module=/src/njs/nginx \
    --add-module=/src/lua-nginx-module && \
# Build & Install
    make -j "$(nproc)" && \
    make -j "$(nproc)" install && \
    strip -s /usr/local/nginx/sbin/nginx && \
    cd /src/lua-resty-core && \
    make install PREFIX=/usr/local/nginx && \
    cd /src/lua-resty-lrucache && \
    make install PREFIX=/usr/local/nginx

FROM alpine:3.18.5
COPY --from=build /usr/local/nginx /usr/local/nginx
RUN apk add --no-cache ca-certificates tzdata zlib luajit pcre libstdc++ yajl libxml2 libxslt perl lua5.1-libs && \
    ln -sf /usr/local/nginx/sbin/nginx /usr/local/bin/nginx
STOPSIGNAL SIGQUIT

WORKDIR /usr/local/nginx

CMD ["nginx", "-g", "daemon off;", "-c", "/etc/config/nginx/conf/nginx.conf"]
