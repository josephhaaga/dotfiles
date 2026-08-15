FROM ubuntu:24.04

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        build-essential ca-certificates curl git jq zsh \
        libasound2t64 libgbm1 libgtk-3-0 libnss3 \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --shell /bin/zsh developer
COPY --chown=developer:developer . /home/developer/dotfiles
USER developer
WORKDIR /home/developer/dotfiles
ENV DOTFILES_PROFILE=container
ENV PATH="/home/developer/.local/bin:/home/developer/.local/share/mise/shims:${PATH}"

RUN ./setup
RUN bash scripts/smoke-test.sh
