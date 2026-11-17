# =============================================
# 1. Go Backend Builder
# =============================================
FROM golang:1.27.3-alpine AS builder
ENV CGO_ENABLED=0
WORKDIR /backend
COPY backend/go.* .
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go mod download
COPY backend/. .
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go build -trimpath -ldflags="-s -w" -o bin/service

# =============================================
# 2. Node.js UI Builder
# =============================================
FROM --platform=$BUILDPLATFORM node:18.12-alpine3.16 AS client-builder
WORKDIR /ui
COPY ui/package.json /ui/package.json
COPY ui/package-lock.json /ui/package-lock.json
RUN --mount=type=cache,target=/usr/src/app/.npm \
    npm set cache /usr/src/app/.npm && \
    npm ci
COPY ui /ui
RUN npm run build

# =============================================
# 3. Final Alpine Stage (Railway Compatible)
# =============================================
FROM alpine

RUN apk add --no-cache bash curl

# Copy built binaries and UI assets from builders
COPY --from=builder /backend/bin/service /service
COPY --from=client-builder /ui/build /ui

# Railway ၏ PORT variable ကို ဖမ်းယူပြီး service စတင်ရန် Startup script ဖန်တီးခြင်း
RUN printf '#!/bin/sh\n\
PORT="${PORT:-8080}"\n\
echo "Starting service on port $PORT..."\n\
exec /service -port "$PORT"\n' > /start.sh \
    && chmod +x /start.sh

EXPOSE 8080

CMD ["/start.sh"]
