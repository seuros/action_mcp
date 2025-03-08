threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count


workers 3
# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
port ENV.fetch("PORT", 3001)
