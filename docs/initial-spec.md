# CodeQuick

CodeQuick is a command-line tool for managing code project directories. It creates directories with unique names inside a central directory. Those unique names are random and don't mean anything to the user, so it creates symlinks with user-defined names. It lets the user quickly make copies of existing project directories, which will be useful for cases like comparisons, experimental refactors and evaluating AI coding agents, without messing up the original directory's state.

## Notes

- Real project directories must not be renamed as that causes inconveniences. For example, Cursor IDE keys the chat history by the directory path, so changing the path results in the loss of chat history. One of the main benefits of this tool is that it lets the user change the project name (by changing the symlink name and VSCode workspace window title) without changing the real directory name.
- Since real directory names will be gibberish, the user won't be able to use tools like Autojump efficiently. So this tool should let the user find projects with fuzzy search and `cd` into that directory easily.
- It shouldn't allow duplicate link names.

## Commands

- `cq ls`: Using fzf, lists the symlinks in the `links` folder in a fuzzy-searchable way. If the user presses Enter in fzf, the link name is copied to the macOS clipboard.
- `cq cd`: Using fzf, lists the symlinks in the `links` folder in a fuzzy-searchable way. If the user presses Enter in fzf, the shell cd's into the selected symlink.
- `cq mk <LINK_NAME>`: Creates a new project in the `reals` directory, sanitizes the link name as kebab-case, and creates the symlink in the `links` folder.
- `cq cp <LINK_NAME> <NEW_LINK_SUFFIX>`: Copies the corresponding real directory, sanitizes the suffix as kebab-case, and creates the symlink for the new copy with the name `${LINK_NAME}__${NEW_LINK_SUFFIX}` in the `links` folder.
- `cq rm <LINK_NAME>`: Sends the real directory and the symlink to the macOS trash.
- `cq rename <LINK_NAME> <NEW_LINK_NAME>`: Sanitizes the new link name as kebab-case, and renames the symlink.
- `cq path <LINK_NAME>`: Prints the absolute path of the real directory.

## Implementation notes

- This will be implemented with shell scripting. Primary target is Zsh. Bash compatibility would be nice to have.
- The directory named by the `CQ_ROOT` environment variable contains the "reals" and "links" directories.
- macOS has a builtin `trash` command now.
- `rm` should move both the link and the real dir to Trash atomically and error clearly if either side is missing or out of sync.
- For unique real directory names we'll make use of `mktemp`. The randomness will be prefixed with "cq-".

## Example commands

Note: We used names like "000001" for illustration purposes. In practice, the names will be random.

```sh
# mk
/> mkdir reals/000001
/links/> ln -s ../reals/000001 ./251103-apple
# TODO Change window title

# cp
/> cp -a -c reals/$(basename $(readlink links/251103-apple))/ reals/000002/
/links/> ln -s ../reals/000002 ./251103-apple__copy1
# TODO Change window title

# pull
/reals/000001/> git pull --ff-only ../$(basename $(readlink ../../links/251103-apple__copy1)) main
# In the end, the user will use `cq path` to get the real directory path

# rename
/> mv links/251103-apple__copy1 links/251103-apple__copy_claude
# TODO Change window title

# ls
/links/> cd $(fd | fzf)

# rm
/> trash reals/$(basename $(readlink links/251103-apple__copy_claude))
/> trash links/251103-apple__copy_claude
```
