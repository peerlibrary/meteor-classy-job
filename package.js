Package.describe({
  name: 'peerlibrary:classy-job',
  summary: "Class-based wrapper around job collection",
  version: '0.1.0',
  git: 'https://github.com/peerlibrary/meteor-classy-job.git'
});

Package.onUse(function (api) {
  api.versionsFrom('1.2.0.2');

  // Core dependencies.
  api.use([
    'coffeescript',
    'underscore',
    'logging',
    'random',
    'ejson'
  ]);

  // 3rd party dependencies.
  api.use([
    'vsivsi:job-collection@1.2.3',
    'peerlibrary:stacktrace@0.2.0'
  ]);

  api.export('Job', 'server');
  api.export('JobsWorker');

  api.addFiles([
    'lib.coffee'
  ]);

  api.addFiles([
    'jobcollection.coffee',
    'job.coffee',
    'worker.coffee'
  ], 'server');
});
