> ## Documentation Index
>
> Fetch the complete documentation index at: #index
> Use this file to discover all available pages before exploring further.

# Shipyard CLI

> Shipyard CLI is a command-line tool that you may use to manage your shipyard resources from the command-line.

<CardGroup cols={2}>
  <Card title="Shipyard CLI" icon="github" href="https://github.com/its9xquoc/shipyard-cli">
    View the Shipyard CLI on GitHub
  </Card>

  <Card title="Shipyard API" icon="code" href="#">
    View the Shipyard API documentation
  </Card>
</CardGroup>

## Introduction

Shipyard provides a command-line tool that you may use to manage your shipyard servers, sites, and resources from the command-line.

## Installation

> **Requires [PHP 8.0+](https://php.net/releases/)**

You may install the **[Shipyard CLI](https://github.com/its9xquoc/shipyard-cli)** as a global [Composer](https://getcomposer.org) dependency:

```bash theme={null}
composer global require its9xquoc/shipyard-cli
```

## Get started

To view a list of all available Shipyard CLI commands and view the current version of your installation, you may run the `shipyard` command from the command-line:

```bash theme={null}
shipyard
```

## Authenticating

After you have generated an API token, you should authenticate with your Shipyard account using the login command:

```bash theme={null}
shipyard login
shipyard login --token=your-api-token
```

Alternatively, if you plan to authenticate with Shipyard from your CI platform, you may set a `shipyard_API_TOKEN` environment variable in your CI build environment.

## Current server & switching servers

When managing Shipyard servers, sites, and resources via the CLI, you will need to be aware of your currently active server. You may view your current server using the `server:current` command. Typically, most of the commands you execute using the shipyard CLI will be executed against the active server.

```bash theme={null}
shipyard server:current
```

Of course, you may switch your active server at any time. To change your active server, use the `server:switch` command:

```bash theme={null}
shipyard server:switch
shipyard server:switch staging
```

To view a list of all available servers, you may use the `server:list` command:

```bash theme={null}
shipyard server:list
```

## SSH key authentication

Before performing any tasks using the Shipyard CLI, you should ensure that you have added an SSH key for the `shipyard` user to your servers so that you can securely connect to them. You may have already done this via the shipyard UI. You may test that SSH is configured correctly by running the `ssh:test` command:

```bash theme={null}
shipyard ssh:test
```

To configure SSH key authentication, you may use the `ssh:configure` command. The `ssh:configure` command accepts a `--key` option which instructs the CLI which public key to add to the server. In addition, you may provide a `--name` option to specify the name that should be assigned to the key:

```bash theme={null}
shipyard ssh:configure

shipyard ssh:configure --key=/path/to/public/key.pub --name=sallys-macbook
```

After you have configured SSH key authentication, you may use the `ssh` command to create a secure connection to your server:

```bash theme={null}
shipyard ssh

shipyard ssh server-name
```

## Sites

To view the list of all available sites, you may use the `site:list` command:

```bash theme={null}
shipyard site:list
```

### Initiating deployments

One of the primary features of Shipyard is deployments. Deployments may be initiated via the shipyard CLI using the `deploy` command:

```bash theme={null}
shipyard deploy

shipyard deploy example.com
```

### Updating environment variables

You may update a site's environment variables using the `env:pull` and `env:push` commands. The `env:pull` command may be used to pull down an environment file for a given site:

```bash theme={null}
shipyard env:pull
shipyard env:pull pestphp.com
shipyard env:pull pestphp.com .env
```

Once this command has been executed, the site's environment file will be placed in your current directory. To update the site's environment variables, open and edit this file. When you are done editing the variables, use the `env:push` command to push the variables back to your site:

```bash theme={null}
shipyard env:push
shipyard env:push pestphp.com
shipyard env:push pestphp.com .env
```

If your site is utilizing Laravel's "configuration caching" feature or has queue workers, the new variables will not be used until the site is deployed again.

### Viewing application logs

You may also view a site's logs directly from the command-line. To do so, use the `site:logs` command:

```bash theme={null}
shipyard site:logs
shipyard site:logs --follow              # View logs in realtime

shipyard site:logs example.com
shipyard site:logs example.com --follow  # View logs in realtime
```

### Reviewing deployment output / logs

When a deployment fails, you may review the output / logs via the Shipyard UI's deployment history screen. You may also review the output at any time on the command-line using the `deploy:logs` command. If the `deploy:logs` command is called with no additional arguments, the logs for the latest deployment will be displayed. Or, you may pass the deployment ID to the `deploy:logs` command to display the logs for a particular deployment:

```
shipyard deploy:logs

shipyard deploy:logs 12345
```

### Running commands

Sometimes you may wish to run an arbitrary shell command against a site. The `command` command will prompt you for the command you would like to run. The command will be run relative to the site's root directory.

```
shipyard command

shipyard command example.com

shipyard command example.com --command="php artisan inspire"
```

### Tinker

As you may know, all Laravel applications include "Tinker" by default. To enter a Tinker environment on a remote server using the Shipyard CLI, run the `tinker` command:

```
shipyard tinker

shipyard tinker example.com
```

## Resources

Shipyard provisions servers with a variety of resources and additional software, such as Nginx, MySQL, etc. You may use the shipyard CLI to perform common actions on those resources.

### Checking resource status

To check the current status of a resource, you may use the `{resource}:status` command:

```bash theme={null}
shipyard daemon:status
shipyard database:status

shipyard nginx:status

shipyard php:status      # View PHP status (default PHP version)
shipyard php:status 8.5  # View PHP 8.5 status
```

### Viewing resources logs

You may also view logs directly from the command-line. To do so, use the `{resource}:logs` command:

```bash theme={null}
shipyard daemon:logs
shipyard daemon:logs --follow  # View logs in realtime

shipyard database:logs

shipyard nginx:logs         # View error logs
shipyard nginx:logs access  # View access logs

shipyard php:logs           # View PHP logs (default PHP version)
shipyard php:logs 8.5       # View PHP 8.5 logs
```

### Restarting resources

Resources may be restarted using the `{resource}:restart` command:

```bash theme={null}
shipyard daemon:restart

shipyard database:restart

shipyard nginx:restart

shipyard php:restart      # Restarts PHP (default PHP version)
shipyard php:restart 8.5  # Restarts PHP 8.5
```

### Connecting to resources locally

You may use the `{resource}:shell` command to quickly access a command line shell that lets you interact with a given resource:

```bash theme={null}
shipyard database:shell
shipyard database:shell my-database-name
shipyard database:shell my-database-name --user=my-user
```
