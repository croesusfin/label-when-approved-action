# Label approved pull requests

This GitHub Action applies a label of your choice to pull requests that reach a specified number of approvals.

## Usage

This Action subscribes to [Pull request review events](https://developer.github.com/v3/activity/events/types/#pullrequestreviewevent) which fire whenever pull requests are approved. The action requires two environment variables – the label name to add and the number of required approvals. Optionally you can provide a label name to remove.

```workflow
on: pull_request_review
name: Label approved pull requests
jobs:
  labelWhenApproved:
    name: Label when approved
    runs-on: ubuntu-latest
    steps:
    - name: Label when approved
      uses: croesusfin/label-when-approved-action@master
      env:
        APPROVALS: "2"
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        ADD_LABEL: "approved"
        REMOVE_LABEL: "awaiting-review"
        CHANGE_LABEL: "changes-requested"
```

## License

The Dockerfile and associated scripts and documentation in this project are released under the [MIT License](LICENSE).
