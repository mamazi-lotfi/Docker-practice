FROM nginx:alpine

RUN rm /etc/nginx/conf.d/default.conf

COPY conf.d/*.conf /etc/nginx/conf.d/
COPY certs/ /etc/nginx/certs/

EXPOSE 80 443
