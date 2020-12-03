app-anaconda
=========
A role that installs [Anaconda](https://www.continuum.io/anaconda-overview) or Miniconda.

Notable features:

 * Has a service user that runs several cron jobs to perform housekeeping tasks for a multiuser installation.
 * The service user runs `conda clean` for all users at a predefined interval.
 * The service user installs all software that has been installed in a user's local environment into the base conda environment.
 * End-users don't interact with the base conda environment directly (i.e., it's read-only to all but the service user).  This resolves concurrency/locking issues related to multiple users issuing a `conda install/uninstall` command at the same time.
 * Has post-install/uninstall hooks for `pip` and `conda` to store transaction history in a git repository.  This addresses a current shortcoming of `conda list --revisions`, where this command only accounts for transactions performed via `conda` while not tracking `pip`-based transactions.

Requirements
------------

See [meta/main.yml](meta/main.yml)

Role Variables
--------------

See [defaults/main.yml](defaults/main.yml)

Dependencies
------------

See [meta/main.yml](meta/main.yml)

Example Playbook
----------------

```yml
- hosts: servers
  roles:
    - app-anaconda
```

License
-------

MIT

Author Information
------------------

Andrew Rothstein <andrew.rothstein@gmail.com>

John Pellman <jsp2205@columbia.edu>
