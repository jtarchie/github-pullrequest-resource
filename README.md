# Github Pull Request Resource

Tracks pull requests made to a particular github repo. In the spirit of [Travis
CI](https://travis-ci.org/), a status of pending, success, or failure will be
set on the pull request, which much be explicitly defined in your pipeline.

Please checkout our [CI Pipeline](http://ci.passed.fail/pipelines/jtarchie-pullrequest-resource).

## Deploying to Concourse

You can use the docker image by defining the [resource type](http://concourse.ci/configuring-resource-types.html) in your pipeline YAML.

For example:

```yaml

resource_types:
- name: pull-request
  type: docker-image
  source:
    repository: jtarchie/pr
```

## Source Configuration

* `repo`: *Required.* The repo name on github.
    Example: `jtarchie/pullrequest-resource`

* `access_token`: *Required.* An access token with `repo:status` access is
  required for *public* repos. An access tocken with `repo` access is required for
  *private* repos.

* `uri`: *Optional.* The URI to the github repo. By default, it assumes
  https://github.com/`repo`.

* `base_url`: *Optional* The base URL for the Concourse deployment, used for
  linking to builds. On newer versions of Concourse ( >= v0.71.0) , the resource will
  automatically sets the URL.

* `private_key`: *Optional.* Private key to use when pulling/pushing.
    Example:
    ```
    private_key: |
      -----BEGIN RSA PRIVATE KEY-----
      MIIEowIBAAKCAQEAtCS10/f7W7lkQaSgD/mVeaSOvSF9ql4hf/zfMwfVGgHWjj+W
      <Lots more text>
      DWiJL+OFeg9kawcUL6hQ8JeXPhlImG6RTUffma9+iGQyyBMCGd1l
      -----END RSA PRIVATE KEY-----
    ```

* `api_endpoint`: *Optional.* If the repository is located on a GitHub Enterprise
  instance you need to specify the base api endpoint (e.g. "https://\<hostname\>/api/v3/").

## Behavior

### `check`: Check for new pull requests

Concourse resources always iterate over the latest version. This maps well to
semver and git, but not with pull requests. To find the latests pull
requests, `check` queries for all PRs, selects only PRs without `concourse-ci`
status messages, and then only returns the oldest one from list.

To ensure that `check` can iterate over all PRs, you must explicitly define an
`out` for the PR.

### `in`: Clone the repository, at the given pull request ref

Clones the repository to the destination, and locks it down to a given ref.

Submodules are initialized and updated recursively, there is no option to to disable that, currently.

There is `git config` information set on the repo about the PR, which can be consumed within your tasks.

For example:

```bash
git config --get pullrequest.url    # returns the URL to the pull request
git config --get pullrequest.branch # returns the branch name used for the pull request
git config --get pullrequest.id     # returns the ID number of the PR
```

### `out`: Update the status of a pull request

Set the status message for `concourse-ci` context on specified pull request.

#### Parameters

* `path`: *Required.* The path of the repository to reference the pull request.

* `status`: *Required.* The status of success, failure, error, or pending.

* `context`: *Optional.* The context on the specified pull request
  (defaults to `status`). Any context will be prepended with `concourse-ci`, so
  a context of `unit-tests` will appear as `concourse-ci/unit-tests` on Github.

## Example pipeline

This is what I am currently using to test this resource on Concourse.

```yaml
resources:
- name: repo
  type: pull-request
  source:
    access_token: acecss_token
    private_key: |
      -----BEGIN RSA PRIVATE KEY-----
      My private key.
      -----END RSA PRIVATE KEY-----
    repo: jtarchie/pullrequest-resource
jobs:
- name: test pull request
  plan:
  - get: repo
    trigger: true
  - put: repo
    params:
      path: repo
      status: pending
  - task: do something with git
    config:
      platform: linux
      image: docker:///concourse/git-resource
      run:
        path: sh
        args:
        - -c
        - cd repo && git --no-pager show
      inputs:
      - name: repo
        path: ""
  - put: repo
    params:
      path: repo
      status: success

```

## Tests

Tests can be run two ways, for local feedback and to see how it will run on the resource container.

1. Local, requires `ruby`

  ```sh
  gem install bundler
  bundle install
  bundle exec rspec
  ```
  
1. Container, requires requires `ruby` and `docker`

  ```sh
  gem install bundler
  bundle install
  rake test
  ```
