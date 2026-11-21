FROM debian:bookworm-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl git unzip xz-utils zip libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch 3.44.1 https://github.com/flutter/flutter.git /opt/flutter
ENV PATH="/opt/flutter/bin:${PATH}"
ENV CI=true
WORKDIR /src
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN flutter build web --release --no-pub --no-wasm-dry-run --dart-define=RADAR_API_URL=/api

FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /src/build/web /usr/share/nginx/html
