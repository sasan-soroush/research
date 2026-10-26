# Builds the Excalidraw web app from source so the collaboration server URL
# (a build-time Vite variable) points at your own excalidraw-room instance.
FROM node:24 AS build

# Pin to a known commit of excalidraw/excalidraw master; bump deliberately.
ARG EXCALIDRAW_REF=b7de45e88111f5680ae4bb3c3f3541c7d3b279fe
ARG VITE_APP_WS_SERVER_URL=http://localhost:8080

WORKDIR /opt/node_app
RUN git clone https://github.com/excalidraw/excalidraw.git . \
 && git checkout "$EXCALIDRAW_REF"

RUN --mount=type=cache,target=/usr/local/share/.cache/yarn \
    yarn --frozen-lockfile --network-timeout 600000

# Vite gives variables already in the environment priority over .env.production.
ENV VITE_APP_WS_SERVER_URL=$VITE_APP_WS_SERVER_URL \
    VITE_APP_ENABLE_TRACKING=false \
    NODE_ENV=production
RUN yarn build:app:docker

FROM nginx:stable-alpine-slim
COPY --from=build /opt/node_app/excalidraw-app/build /usr/share/nginx/html
HEALTHCHECK CMD wget -q -O /dev/null http://localhost || exit 1
