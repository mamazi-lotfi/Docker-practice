FROM nginx:alpine

# حذف کانفیگ پیش‌فرض nginx
RUN rm /etc/nginx/conf.d/default.conf

# کپی کردن کانفیگ سفارشی وردپرس
COPY wordpress.conf /etc/nginx/conf.d/wordpress.conf

# کپی کردن گواهی SSL
COPY certs/wordpress.crt /etc/nginx/certs/wordpress.crt
COPY certs/wordpress.key /etc/nginx/certs/wordpress.key

EXPOSE 80 443
