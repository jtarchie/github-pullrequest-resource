# Github Pull Request Resource

Tracks pull requests made to a particular github repo. In the spirit of [Travis
CI](https://travis-ci.org/), a status of pending, success, or failure will be
set on the pull request, which much be explicitly defined in your pipeline.

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

* `every`: *Optional* If set to `true`, it will override the `check` step so every pull request can be iterated
through, without relying on a status being on it. This feature should only be used in
concourse version 1.2.x and higher and the [`version: every`](http://concourse.ci/get-step.html#get-version).

* `username`: *Optional.* Username for HTTP(S) auth when pulling/pushing.
  This is needed when only HTTP/HTTPS protocol for git is available (which does not support private key auth)
  and auth is required.

* `password`: *Optional.* Password for HTTP(S) auth when pulling/pushing.

* `skip_ssl_verification`: *Optional.* Skips git ssl verification by exporting
  `GIT_SSL_NO_VERIFY=true`.

* `git_config`: *Optional*. If specified as (list of pairs `name` and `value`)
  it will configure git global options, setting each name with each value.

  This can be useful to set options like `credential.helper` or similar.

  See the [`git-config(1)` manual page](https://www.kernel.org/pub/software/scm/git/docs/git-config.html)
  for more information and documentation of existing git options.

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

#### Parameters

* `fetch_merge`: *Optional*. If set to `true`, it will fetch what the result of PR
  would be otherwise it will fetch the origin branch.
  Defaults to `false`.

### `out`: Update the status of a pull request

Set the status message for `concourse-ci` context on specified pull request.

#### Parameters

* `path`: *Required.* The path of the repository to reference the pull request.

* `status`: *Required.* The status of success, failure, error, or pending.
  * [`on_success`](https://concourse.ci/on-success-step.html) and [`on_falure`](https://concourse.ci/on-failure-step.html) triggers may be useful for you when you wanted to reflect build result to the PR (see the example below).

* `context`: *Optional.* The context on the specified pull request
  (defaults to `status`). Any context will be prepended with `concourse-ci`, so
  a context of `unit-tests` will appear as `concourse-ci/unit-tests` on Github.

* `comment`: *Optional.* The file path of the comment message. Comment owner is same with the owner of `access_token`.

## Example pipeline

This is what I am currently using to test this resource on Concourse.

```yaml
resource_types:
- name: pull-request
  type: docker-image
  source:
    repository: jtarchie/pr
resources:
- name: repo
  type: pull-request
  source:
    access_token: access_token
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
    on_success:
      put: repo
      params:
        path: repo
        status: success
    on_failure:
      put: repo
      params:
        path: repo
        status: failure
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
