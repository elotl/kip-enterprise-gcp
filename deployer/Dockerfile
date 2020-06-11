ARG MARKETPLACE_TOOLS_TAG
FROM launcher.gcr.io/google/debian9 AS build

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl detox gettext git

RUN curl -fsL https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv3.6.1/kustomize_v3.6.1_linux_amd64.tar.gz | tar -C /usr/local/bin/ -xvzf - && chmod +x /usr/local/bin/kustomize

ADD schema.yaml /tmp/schema.yaml

# Provide registry prefix and tag for default values for images.
ARG REGISTRY
ARG TAG
RUN cat /tmp/schema.yaml \
    | env -i "REGISTRY=$REGISTRY" "TAG=$TAG" envsubst \
    > /tmp/schema.yaml.new \
    && mv /tmp/schema.yaml.new /tmp/schema.yaml

COPY kustomize /tmp/kustomize/
RUN mkdir /tmp/kustomize-output
RUN kustomize build /tmp/kustomize -o /tmp/kustomize-output
RUN rm -f \
        /tmp/kustomize-output/*_clusterrole_* \
        /tmp/kustomize-output/*_clusterrolebinding_* \
        /tmp/kustomize-output/*_serviceaccount_*
RUN bash -c \
        "cd /tmp/kustomize-output/ && \
        find . -type f -exec detox '{}' \; && \
        ls -l"


FROM gcr.io/cloud-marketplace-tools/k8s/deployer_envsubst:$MARKETPLACE_TOOLS_TAG

COPY manifest /data/manifest
COPY apptest/deployer /data-test/
COPY --from=build /tmp/schema.yaml /data/
COPY --from=build /tmp/kustomize-output /data/manifest/
