# check_everything

## Open frequently accessed websites from your command line, in one go!
####(Also includes the ability to find documentation for the Ruby core classes)

### Install

Type `gem install check_everything` into the command line.

### Run

Type `check_everything` into the command line to pull up the default URLs.

You can add the following tags (listed in order of precedence; only the first
will be evaluated):

|   Tag |  Result   |
|-----|-----|
|  \-h, \-\-help         | display the help message                          |
|  \-l, \-\-links        | view/edit links and categories                    |
|  \-r, \-\-ruby         | install Ruby Documentation functionality          |
|  \-c, \-\-categories   | view the currently defined categories             |
|  \-a, \-\-all          | open all websites                                 |
|  &#60;category&#62;    | open a specific site group                        |
|  &#60;Ruby class&#62;  | open Ruby documentation (if feature is installed) |


### Configure

On your first run, you will be asked to do 2 things:

1. Choose whether to install Ruby Documentation lookup functionality. This will
give you command-line access to the online Ruby Documentation for the Core classes
for your currently running version of Ruby. For example, to see documentation for
array, type `check_everything array`.

2. Input your URLs and customize your categories! Check out the instructions in
the configuration file.

### Update Your Bash Profile (optional)

You can update your Bash profile (~/.bash_profile) with:
```alias check="check_everything"```
to just type `check` instead of `check_everything` and make things even simpler!

### Enjoy!

If you have any comments or want to suggest improvements, please feel free to fork
and submit a pull request.

The latest version: [![Gem Version](https://badge.fury.io/rb/check_everything.png)](http://badge.fury.io/rb/check_everything)