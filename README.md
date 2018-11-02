# Github page for sidekiq-scheduler

Visit http://moove-it.github.io/sidekiq-scheduler/

## Install dependencies

```shell
cd app
yarn install
```

## Making changes

Make approapriate change in `app/` directory. Don't edit any asset outside `app/`, changes there will be overwritten on every build.

To test your changes run:

```shell
cd app
yarn start
```

And then go to http://localhost:3000


## Deploy

The following command will build, and push into gh-pages branch.

```shell
cd app
./build.sh
```

Then check by going to http://moove-it.github.io/sidekiq-scheduler/