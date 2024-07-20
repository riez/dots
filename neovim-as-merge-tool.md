# git

## Using diffview.nvim

```ini
# ~/.gitconfig
[merge]
  tool = diffview
[mergetool]
  prompt = false
  keepBackup = false
[mergetool "diffview"]
  cmd = nvim -n -c "DiffviewOpen" "$MERGE"
```

## Using git default `nvimdiff`

```ini
# ~/.gitconfig
[merge]
  tool = nvimdiff
[mergetool]
  prompt = false
  keepBackup = false
[mergetool "nvimdiff"]
  layout = "LOCAL,BASE,REMOTE / MERGED"
```

## Usage

```shell
$ git merge other-branch
# oops, conflicts!
$ git mergetool
```

# hg

## Using diffview.nvim

```ini
# ~/.hgrc
[ui]
merge = internal:merge
[extensions]
purge =
[alias]
mergetool = !nvim -n -c "DiffviewOpen" && hg resolve --mark && hg purge -I **/*.orig --all
```

## Using neovim diff-mode

```ini
# ~/.hgrc
[ui]
merge = nvimdiff
[extensions]
purge =
[hooks]
post-merge = hg purge -I **/*.orig --all
[merge-tools]
nvimdiff.executable = nvim
nvimdiff.args = -d $output -M $local $base $other -c "wincmd J" -c "set modifiable" -c "set write" -c "nnoremap co :diffget 2<cr>" -c "nnoremap ct :diffget 4<cr>"
nvimdiff.premerge = keep
nvimdiff.check = conflicts
```

## Usage

```shell
$ hg merge other-branch
# oops, conflicts!
# If using diff-mode, the neovim will be opened automatically after conflicts occurred
$ hg mergetool  # for diffview.nvim
```

# Refs

1. [diff-mode](https://neovim.io/doc/user/diff.html)
2. [sindrets/diffview.nvim](https://github.com/sindrets/diffview.nvim)
3. [mergetools/vimdiff.txt](https://github.com/git/git/blob/master/Documentation/mergetools/vimdiff.txt)
4. [hgrc merge-tools](https://www.mercurial-scm.org/doc/hgrc.5.html#merge-tools)
5. [MergingWithVim](https://wiki.mercurial-scm.org/MergingWithVim)
6. [How to use `git mergetool` to resolve conflicts in Vim / NeoVim](https://gist.github.com/karenyyng/f19ff75c60f18b4b8149/e6ae1d38fb83e05c4378d8e19b014fd8975abb39)
7. [Neovim As Git Mergetool](https://smittie.de/posts/git-mergetool/)
8. [Using Vim or NeoVim as a Git mergetool](https://www.grzegorowski.com/using-vim-or-neovim-nvim-as-a-git-mergetool)
