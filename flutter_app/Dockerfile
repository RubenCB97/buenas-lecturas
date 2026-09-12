# Etapa 1: Construir Flutter Web
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app
COPY pubspec.* ./
RUN flutter pub get

COPY . .
# Compilar para web
RUN flutter build web --release --dart-define=API_URL=https://buenas-lecturas.costacode.es/api

# Etapa 2: Servidor Nginx
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
