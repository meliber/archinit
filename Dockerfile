FROM archlinux:latest

COPY ./public_keys.txt .
COPY ./archinit_docker.sh .
RUN set -x; chmod +x ./archinit_docker.sh \
    && ./archinit_docker.sh \
    && rm -rf /var/cache/pacman/pkg public_keys.txt archinit.sh \
    && ssh-keygen -A

# start ssh server during container startup
CMD ["/usr/sbin/sshd", "-D"]
