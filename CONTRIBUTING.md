Thanks for your interest in contributing to Cloudera Director scripts!

The Cloudera Director scripts project is an Apache-licensed, open source project associated with [Cloudera Director](https://www.cloudera.com/products/product-components/cloudera-director.html). This document contains guidelines for how to contribute to the project.

# How do I contribute code?

You need to sign and return an ["Individual Contributor Licensing Agreement" (ICLA)](Cloudera%20ICLA_25APR2018.pdf) and, if you’re contributing as part of your job, a ["Corporate Contributor Licensing Agreement" (CCLA)](Cloudera%20CCLA_25APR2018.pdf) as well. A submitted ICLA and CCLA are required before we can accept and redistribute your contribution. Once the agreements are signed, send them to CLA@cloudera.com. Then, you are free to start contributing.

If you submit a CCLA and then change jobs, please submit a new CCLA for your new employer before resuming your contributions. If you are only working under an ICLA, a new submission is not necessary.

## Find

Find an issue that you would like to work on, or file one if you have discovered something new. If no one is working on the issue, assign it to yourself only if you intend to work on it shortly.

Except for the very smallest items, it’s a very good idea to discuss your intended approach in the comment stream of the issue. You are much more likely to have your pull request reviewed and committed if you’ve already gotten buy-in from the rest of the community before you start.

## Fix

Now start coding! For best results, first fork this repository, and then create a feature branch in your clone to house your work. (You can reuse your fork for subsequent work.)

As you are working, keep the following things in mind:

First, please include tests with your changes where appropriate. If code changes do not include tests, it is much less likely that they will be accepted. If you are unsure how to write tests, please ask on the issue comment stream for guidance. You should also try using your updates on a recent release of Cloudera Director, to be sure that they integrate successfully and work as intended in a live scenario.

Second, please keep your changes narrowly targeted to the problem described by the issue. It’s better for everyone if we maintain discipline about the scope of each change set. In general, if you find a bug while working on a specific feature, file a separate issue for the bug, check if you can assign it to yourself, and fix it independently of the feature. This helps the community differentiate between bug fixes and features, and allows us to build stable maintenance releases.

Finally, please write a good, clear commit message, with a short, descriptive title and a message that is exactly long enough to explain what the problem was, and how it was fixed. [This guidance](https://chris.beams.io/posts/git-commit/) is what we like to refer to. If your work spans multiple commits, squash them before creating a pull request.

## Submit

When the changes are ready to go, submit a pull request against the main repository from the branch on your fork. To help get attention from the community, assign reviewers to the pull request that you have been communicating with and who have permission to merge pull requests. Work with reviewers to make any necessary final adjustments to your work. When the discussion is complete, your pull request will be merged. Congratulations!

Once your changes are merged, Cloudera staff will import them into the copies maintained along with Cloudera Director code itself, so that later versions of Cloudera Director will automatically include them.
