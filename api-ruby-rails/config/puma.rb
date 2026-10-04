# Ruby threads share one GVL per process, so throughput comes from forking
# workers. Workers x threads is kept equal to DB_POOL_SIZE connections.
threads_count = Integer(ENV.fetch("RAILS_MAX_THREADS", 2))
pool_size = Integer(ENV.fetch("DB_POOL_SIZE", 10))

threads threads_count, threads_count
workers Integer(ENV.fetch("WEB_CONCURRENCY") { [pool_size / threads_count, 1].max })
preload_app!

port ENV.fetch("PORT", 8080)
environment ENV.fetch("RAILS_ENV", "production")
