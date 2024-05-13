build:
    mix deps.get
    mix compile

repl:
    iex -S mix

checkpoint:
	git add -A
	git commit -m "checkpoint at `date '+%Y-%m-%dT%H:%M:%S%z'`"
	git push
	echo "Checkpoint created and pushed to remote"