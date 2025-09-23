FROM grafana/promtail:2.9.0
COPY promtail.yml /etc/promtail/config.yml
