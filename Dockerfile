# syntax=docker/dockerfile:labs
FROM alpine:3.20.1 as build
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

ARG LUAJIT_INC=/usr/include/luajit-2.1
ARG LUAJIT_LIB=/usr/lib

ARG NGINX_VER=1.27.0
ARG OPENSSL_VER=openssl-3.3.0+quic
ARG MODSEC_VER=v3.0.12

ARG DTR_VER=1.25.1
ARG RCP_VER=1.25.3

ARG NB_VER=master
ARG NF_VER=master
ARG HMNM_VER=v0.37
ARG NJS_VER=0.8.4
ARG NDK_VER=v0.3.3
ARG LNM_VER=v0.10.26
ARG MODSECNGX_VER=v1.0.3
ARG LRC_VER=v0.1.28
ARG LRL_VER=v0.13
ARG NHG2M_VER=3.4

WORKDIR /src
# Requirements
RUN apk upgrade --no-cache -a && \
    apk add --no-cache ca-certificates build-base patch cmake git libtool autoconf automake perl \
    libatomic_ops-dev zlib-dev luajit-dev pcre2-dev linux-headers yajl-dev libxml2-dev libxslt-dev curl-dev lmdb-dev libfuzzy2-dev lua5.1-dev lmdb-dev geoip-dev libmaxminddb-dev
# Openssl
RUN git clone https://github.com/quictls/openssl --branch "$OPENSSL_VER" /src/openssl
# Nginx
RUN wget -q https://nginx.org/download/nginx-"$NGINX_VER".tar.gz -O - | tar xzC /src && \
    mv /src/nginx-"$NGINX_VER" /src/nginx && \
    sed -i "s|nginx/|NPMplus/|g" /src/nginx/src/core/nginx.h && \
    sed -i "s|Server: nginx|Server: NPMplus|g" /src/nginx/src/http/ngx_http_header_filter_module.c && \
    sed -i "s|<hr><center>nginx</center>|<hr><center>NPMplus</center>|g" /src/nginx/src/http/ngx_http_special_response.c && \
    cd /src/nginx && \
    # modules
    git clone --recursive https://github.com/google/ngx_brotli --branch "$NB_VER" /src/ngx_brotli && \
    git clone --recursive https://github.com/openresty/headers-more-nginx-module --branch "$HMNM_VER" /src/headers-more-nginx-module && \
    git clone --recursive https://github.com/nginx/njs --branch "$NJS_VER" /src/njs && \
    git clone --recursive https://github.com/openresty/lua-nginx-module --branch "$LNM_VER" /src/lua-nginx-module && \
    # Configure
    RUN cd /src/nginx && \
    /src/nginx/configure \
    --build="2" \
    --with-compat \
    --with-threads \
    --with-file-aio \
    --with-libatomic \
    --with-pcre \
    --with-pcre-jit \
    --with-openssl="/src/openssl" \
    --with-mail \
    --with-mail_ssl_module \
    --with-ld-opt="-L/src/openssl/build/lib" \
    --with-cc-opt="-I/src/openssl/build/include" \
    --with-openssl-opt=no-weak-ssl-ciphers \
    --with-openssl-opt=no-ssl2 \    
    --with-openssl-opt=no-ssl3 \    
    --with-stream \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --with-stream_geoip_module \
    --with-stream_realip_module \
    --with-http_v2_module \
    --with-http_v3_module \
    --with-http_ssl_module \
    --with-http_geoip_module \
    --with-http_realip_module \
    --with-http_gunzip_module \
    --with-http_addition_module \
    --with-http_gzip_static_module \
    --with-http_auth_request_module \
    --with-http_geoip_module \
    --with-http_sub_module \
    --with-http_stub_status_module \
    --add-module=/src/ngx_brotli \
    --add-module=/src/headers-more-nginx-module \
    --add-module=/src/njs/nginx \
    --add-module=/src/lua-nginx-module

    # Build & Install
RUN cd /src/nginx && \
    make -j "$(nproc)" && \
    make -j "$(nproc)" install && \
    strip -s /usr/local/nginx/sbin/nginx

FROM alpine:3.20.1
COPY --from=build /usr/local/nginx                               /usr/local/nginx
RUN apk upgrade --no-cache -a && \
    apk add --no-cache ca-certificates tzdata zlib luajit pcre2 libstdc++ yajl libxml2 libxslt libcurl lmdb libfuzzy2 lua5.1-libs geoip libmaxminddb-libs && \
    ln -s /usr/local/nginx/sbin/nginx /usr/local/bin/nginx
STOPSIGNAL SIGQUIT

WORKDIR /usr/local/nginx

CMD ["nginx", "-g", "daemon off;", "-c", "/etc/config/nginx/conf/nginx.conf"]