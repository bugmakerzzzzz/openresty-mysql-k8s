FROM openresty/openresty
COPY openresty-mysql-k8s /src
WORKDIR /src
CMD nginx -p `pwd`/ -c conf/nginx.conf