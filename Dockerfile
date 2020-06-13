FROM alpine:latest

RUN apk add --no-cache curl tini

RUN addgroup -g 1000 -S local && \
    adduser -u 1000 -S local -G local

ARG script_name="update-ip.sh"
ADD "${script_name}" "/usr/bin"

# default cron job frequency in minutes (can be overridden at runtime)
ENV FREQUENCY=15

ARG cron_dir="/etc/periodic/custom"
WORKDIR "${cron_dir}"

# make sure script runs without root priviledges
# NOTE: no suffix ".sh" allowed!
# see https://gist.github.com/andyshinn/3ae01fa13cb64c9d36e7#gistcomment-2044506
RUN echo -e "#!/bin/sh\nsu -s /bin/sh local -c \'${script_name}\'" > "run_me_no_root" && \
    chmod +x "run_me_no_root"

# backup crontab and create a new one with only the frequency that we need
# "%VAR" is a placeholder that is replaced by sed in the "start-me.sh" script defined below
RUN mv "/var/spool/cron/crontabs/root" "/var/spool/cron/crontabs/root.bak" && \
    echo "*/%VAR% * * * * run-parts \"${cron_dir}\"" > "/var/spool/cron/crontabs/root"

# create script "start-me.sh" that replaces cron job frequency at runtime and starts crond
RUN echo -e '#!/bin/sh\n\
    FREQ=${FREQUENCY:-'${FREQUENCY}'}\n\
    sed -i -E "s/%VAR%/${FREQ}/" "/var/spool/cron/crontabs/root"\n\
    echo "Cron frequency: ${FREQ} min"\n\
    # using exec is essential to ensure signals are forwarded\n\
    exec crond -l 1 -f\n' > "/usr/bin/start-me.sh" && \
    chmod +x "/usr/bin/start-me.sh"

# using tini https://github.com/krallin/tini
ENTRYPOINT [ "/sbin/tini", "--", "/usr/bin/start-me.sh" ]
