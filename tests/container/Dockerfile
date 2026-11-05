FROM ubuntu:24.04

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        build-essential ca-certificates curl git jq zsh \
        libasound2t64 libgbm1 libgtk-3-0 libnss3 \
    && rm -rf /var/lib/apt/lists/*

RUN installer="$(mktemp)" \
    && curl -fsSL https://mise.jdx.dev/v2026.8.6/install.sh -o "$installer" \
    && echo "18ec854e24388880277a84e73434114eb80cdf2066afcf3671fed2682cb1ea4a  $installer" | sha256sum -c - \
    && MISE_VERSION=v2026.8.6 MISE_INSTALL_PATH=/usr/local/bin/mise sh "$installer" \
    && rm -f "$installer"

RUN useradd --create-home --shell /bin/zsh developer
COPY --chown=developer:developer . /home/developer/dotfiles
USER developer
WORKDIR /home/developer/dotfiles
ENV DOTFILES_PROFILE=container
ENV PATH="/home/developer/.local/bin:/home/developer/.local/share/mise/shims:${PATH}"

RUN mise x chezmoi@2.72.0 -- chezmoi init --apply --source /home/developer/dotfiles
RUN bash scripts/smoke-test.sh
