DEFAULT_JOB_TIMEOUT = 5 * 60 * 1000 # ms

# We cannot directly extend Error type, because instanceof check does not work correctly,
# but we can use makeErrorType. Extending an error made with makeErrorType further works.
FatalJobError = Meteor.makeErrorType 'FatalJobError',
  (message) ->
    @message = message or ''

isPlainObject = (obj) ->
  if not _.isObject(obj) or _.isArray(obj) or _.isFunction(obj)
    return false

  if obj.constructor isnt Object
    return false

  return true

class Job
  @types: {}
  @timeout: DEFAULT_JOB_TIMEOUT

  constructor: (@data) ->
    @data ||= {}

  run: ->
    throw new @constructor.FatalJobError "Not implemented."

  # Method so that job class can set or override enqueue options.
  enqueueOptions: (options) ->
    options or {}

  # Method so that job class can set or override skipping logic.
  shouldSkip: (options) ->
    # There is a race-condition here, but in the worst case there will be
    # some duplicate work done. Jobs ought to be idempotent anyway.
    return options?.skipIfExisting and @constructor.exists @data, options?.skipIncludingCompleted

  enqueue: (options) ->
    throw new @constructor.FatalJobError "Unknown job class '#{@type()}'." unless Job.types[@type()]

    return if @shouldSkip options

    job = JobsWorker._createJob @type(), @data

    options = @enqueueOptions options

    job.depends options.depends if options?.depends?
    job.priority options.priority if options?.priority?
    job.retry options.retry if options?.retry?
    job.repeat options.repeat if options?.repeat?
    job.delay options.delay if options?.delay?
    job.after options.after if options?.after?

    job.save options?.save

  # You should query yourself the database if you want the recent document from the database.
  getQueueJob: ->
    JobsWorker._makeJob
      _id: @_id
      runId: @runId
      type: @type()
      data: @data

  log: (message, options, callback) ->
    @getQueueJob().log message, options, callback

  _logWithLevel: (level, message, data, callback) ->
    options =
      level: level

    # Data is optional.
    if _.isFunction data
      callback = data
      data = null
    else if data
      options.data = data

    @log message, options, callback

  logInfo: (message, data, callback) ->
    @_logWithLevel 'info', message, data, callback

  logSuccess: (message, data, callback) ->
    @_logWithLevel 'success', message, data, callback

  logWarning: (message, callback) ->
    @_logWithLevel 'warning', message, data, callback

  logDanger: (message, callback) ->
    @_logWithLevel 'danger', message, data, callback

  progress: (completed, total, options, callback) ->
    @getQueueJob().progress completed, total, options, callback

  type: ->
    @constructor.type()

  @type: ->
    @name

  @register: (jobClass) ->
    # To allow calling @register() from inside a class body.
    jobClass ?= @

    throw new Error "Job class '#{jobClass.name}' is not a subclass of Job class." unless jobClass.prototype instanceof Job
    throw new Error "Job class '#{jobClass.type()}' already exists" if jobClass.type() of @types

    @types[jobClass.type()] = jobClass

  @FatalJobError: FatalJobError

  @fromQueueJob: (queueJob) ->
    jobClass = @types[queueJob.type]
    jobInstance = new jobClass queueJob.data
    jobInstance._id = queueJob._doc._id
    jobInstance.runId = queueJob._doc.runId
    jobInstance

  @_constructQuery: (data) ->
    values = (path, doc) ->
      res = {}
      for field, value of doc
        newPath = if path then "#{path}.#{field}" else field
        if isPlainObject value
          _.extend res, values newPath, value
        else
          res[newPath] = value
      res

    query = values '', data
    query.type = @type()

  # Raw query, without assuring that the resulting document is of the same type.
  # TODO: Implement that if it is called on a subclass that it limits the query only to that type.
  @find: (query={}, options={}) ->
    # We require calling on Job for now.
    throw new Error "Not supported." if @ isnt Job

    options = _.defaults options,
      fields:
        _private: 0
        log: 0
        failures: 0

    JobsWorker.collection.find query, _.extend {}, options,
      transform: (document) =>
        @fromQueueJob JobsWorker._makeJob document

  # Raw query, without assuring that the resulting document is of the same type.
  # TODO: Implement that if it is called on a subclass that it limits the query only to that type.
  @findOne: (query={}, options={}) ->
    # We require calling on Job for now.
    throw new Error "Not supported." if @ isnt Job

    options = _.defaults options,
      fields:
        _private: 0
        log: 0
        failures: 0

    JobsWorker.collection.findOne query, _.extend {}, options,
      transform: (document) =>
        @fromQueueJob JobsWorker._makeJob document

  # This query limits the results only to documents of the same type. So "Job.findData" will not return
  # anything, but "ExampleJob.findData" (where ExampleJob is a subclass of Job) might.
  # TODO: Implement that if it is called on Job it does not limit the type.
  @findData: (data, options) ->
    # We require calling on subclass for now.
    throw new Error "Not supported." if @ is Job

    query = @_constructQuery()
    @find query, options

  # This query limits the results only to documents of the same type. So "Job.findDataOne" will not return
  # anything, but "ExampleJob.findDataOne" (where ExampleJob is a subclass of Job) might.
  # TODO: Implement that if it is called on Job it does not limit the type.
  @findDataOne: (data, options) ->
    # We require calling on subclass for now.
    throw new Error "Not supported." if @ is Job

    query = @_constructQuery()
    @findOne query, options

  @exists: (data, includingCompleted) ->
    # Cancellable job statuses are in fact the same as those we want for existence check.
    statuses = JobsWorker.collection.jobStatusCancellable
    statuses = statuses.concat ['completed'] if includingCompleted

    query = @_constructQuery()
    query.status =
      $in: statuses

    !!JobsWorker.collection.findOne query,
      fields:
        _id: 1
      transform: null
