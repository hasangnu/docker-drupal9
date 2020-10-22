´´´yalm
version: '3.3'
services:
  drupal:
    stdin_open: true
    tty: true
    image: "hasangnu/drupal9:9.0.7"
    ports:
      - 22
      - 7780:80
    volumes:
      - ./local/data:/var/lib/mysql
      - ./local:/var/www/html
    restart: always
´´´
´´´
docker-compose up -d
´´´
