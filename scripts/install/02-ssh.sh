#!/usr/bin/env bash
# Ensures SSH access to this host is installed, running, and has keys ready
# to use, without narrowing how you can log in.
#
# Deliberately does NOT disable password authentication — both password and
# public-key login stay available. See docs/adr/0005-ssh-bootstrap.md for
# why this is a boundary the installer won't cross on its own.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

require_root

# --- Install + enable openssh-server (idempotent: apt no-ops if present) ---
log_info "Ensuring openssh-server is installed..."
apt-get install -y --no-install-recommends openssh-server

log_info "Enabling and starting the ssh service..."
systemctl enable ssh >/dev/null
systemctl start ssh

# --- Config: explicitly keep both password and public-key auth available ---
SSHD_DROPIN=/etc/ssh/sshd_config.d/60-constellation.conf
DESIRED_CONTENT="# Installed by Constellation scripts/install/02-ssh.sh.
# Deliberately keeps both password and public-key authentication available
# (no forced hardening) - see docs/adr/0005-ssh-bootstrap.md.
PasswordAuthentication yes
PubkeyAuthentication yes
"

if [[ -f "${SSHD_DROPIN}" ]] && [[ "$(cat "${SSHD_DROPIN}")" == "${DESIRED_CONTENT}" ]]; then
    log_success "sshd already configured for password + public-key auth, skipping."
else
    log_info "Writing ${SSHD_DROPIN} (keeps password + public-key auth both enabled)..."
    mkdir -p /etc/ssh/sshd_config.d
    printf '%s' "${DESIRED_CONTENT}" > "${SSHD_DROPIN}"
    chmod 644 "${SSHD_DROPIN}"

    if sshd -t; then
        systemctl reload ssh
        log_success "sshd config validated and reloaded."
    else
        log_error "sshd -t reported a config error after writing ${SSHD_DROPIN}. Reverting."
        rm -f "${SSHD_DROPIN}"
        exit 1
    fi
fi

# --- Dedicated automation/deploy key (non-interactive service use) ---
DEPLOY_SSH_DIR=/etc/constellation/ssh
DEPLOY_KEY="${DEPLOY_SSH_DIR}/deploy_ed25519"

install -d -m 700 -o root -g root "${DEPLOY_SSH_DIR}"

if [[ -f "${DEPLOY_KEY}" ]]; then
    log_success "Deploy key already exists: ${DEPLOY_KEY}, skipping."
else
    log_info "Generating dedicated automation/deploy key at ${DEPLOY_KEY}..."
    ssh-keygen -t ed25519 -N "" -C "constellation-deploy@$(hostname)" -f "${DEPLOY_KEY}" -q
    chmod 600 "${DEPLOY_KEY}"
    chmod 644 "${DEPLOY_KEY}.pub"
    log_success "Deploy key generated. Public key: ${DEPLOY_KEY}.pub"
    log_info "This key is for non-interactive/service use (e.g. future automation, CI, host-to-host)."
    log_info "It is not authorized for login to this host or anywhere else until you add its public"
    log_info "key to a target's authorized_keys yourself."
fi

# --- Personal login key for the operator running the installer ---
TARGET_USER="${SUDO_USER:-$(id -un)}"
TARGET_HOME="$(user_home_dir "${TARGET_USER}")"
TARGET_GROUP="$(id -gn "${TARGET_USER}" 2>/dev/null || echo "${TARGET_USER}")"

if [[ -z "${TARGET_HOME}" || ! -d "${TARGET_HOME}" ]]; then
    log_warn "Could not resolve a home directory for '${TARGET_USER}', skipping personal login key."
else
    USER_SSH_DIR="${TARGET_HOME}/.ssh"
    USER_KEY="${USER_SSH_DIR}/id_ed25519"
    AUTHORIZED_KEYS="${USER_SSH_DIR}/authorized_keys"

    install -d -m 700 -o "${TARGET_USER}" -g "${TARGET_GROUP}" "${USER_SSH_DIR}"

    if [[ -f "${USER_KEY}" ]]; then
        log_success "Login key already exists for ${TARGET_USER}: ${USER_KEY}, skipping generation."
    else
        log_info "Generating login key for ${TARGET_USER} at ${USER_KEY}..."
        sudo -u "${TARGET_USER}" ssh-keygen -t ed25519 -N "" -C "${TARGET_USER}@$(hostname)" -f "${USER_KEY}" -q
        log_success "Login key generated: ${USER_KEY}"
        log_warn "Private key was generated on this host. Copy ${USER_KEY} to your client machine and"
        log_warn "remove it here if you want the usual client-generated-key security posture; password"
        log_warn "login remains available in the meantime."
    fi

    touch "${AUTHORIZED_KEYS}"
    chmod 600 "${AUTHORIZED_KEYS}"
    chown "${TARGET_USER}:${TARGET_GROUP}" "${AUTHORIZED_KEYS}"

    PUBKEY_CONTENT="$(cat "${USER_KEY}.pub")"
    if grep -qF "${PUBKEY_CONTENT}" "${AUTHORIZED_KEYS}" 2>/dev/null; then
        log_success "Login key already present in ${AUTHORIZED_KEYS}, skipping."
    else
        echo "${PUBKEY_CONTENT}" >> "${AUTHORIZED_KEYS}"
        log_success "Added login key to ${AUTHORIZED_KEYS}. Both password and key-based login now work for ${TARGET_USER}."
    fi
fi

# --- Fingerprints for out-of-band verification (e.g. via console/IPMI) ---
log_info "Host SSH key fingerprints (compare these on first connect):"
for pub in /etc/ssh/ssh_host_*_key.pub; do
    [[ -f "${pub}" ]] && ssh-keygen -lf "${pub}"
done

log_success "SSH ready: installed, running, password + public-key auth both available."
