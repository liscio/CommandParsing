# CommandParsing

This is a demonstration of my approach for parsing commands using [swift-parsing][swift-parsing].

## Overview

* Your `Command`s are an enum, intended for dispatch somewhere in your app. Perhaps they are `Event`s in [The Composable Architecture][tca], or something else entirely.
* `String`-valued *parser descriptions* specify the parsers you want, and the associated `Command`s that they belong to.
* A top-level `CommandParser` looks up incoming commands in a hash table (i.e. `Dictionary`) rather than relying on `OneOfMany` to do this for you.

That last item is the externally-facing parser for your `Command`s. It looks up the command's name in the hash table, and:
* If found, it parses the parameters and returns the `Command`
* If not, you can provide a helpful hint in the error handler in case the command was misspelled.

## Benefits

* The ability to provide a helpful hint for a misspelled `Command` name
* (Theoretically) faster lookups in the hash table compared to the `O(n)` linear search through all your commands when you use `Parsers.OneOfMany`.

## Future Work

I think that the `CommandParser` approach could *possibly* be generalized/extended for use with the automatic `CaseEnumerable` parsers. Spell checking + compact error output would maybe be nice.

Obviously, this doesn't do spell checking on the list of parameters. Again, a generalized `Parser` that maintains a list of keywords could be helpful.

### Pull requests are welcome

I'd be curious to hear how others might suggest a cleaner approach here. I've already got this working on a ~40 entry long `Command` type of my own, and it's *quite* clean in practice.

## Before you ask…

### Q: Why are you using so much `AnyParser`!? Isn't that SLOW?

I'm not parsing an entire *language* here. Besides, once the hash table lookup is done, the inner parsers are *very small*. This'll cope well with very large dictionaries of commands. 
 
### Q: In a Swift-like syntax, how would you deal with overloading?

I have hit this already in [my own application](https://capoapp.com). The solution is to make the `Value` of the hash table a collection of parsers. Then, in `CommandParser` you can steal the approach from `Parsers.OneOfMany` when you encounter an array with `count > 1`.

### Q: What are you even doing with this?

In [Capo](https://capoapp.com), I am overhauling the MIDI and keyboard shortcut handling so that I can tie more sophisticated commands to the incoming events. E.g. a `noteOn` could trigger `setPlaybackSpeed(to: 50%)` and `noteOff` could trigger `setPlaybackSpeed(to: 100%)`. 

(In case you're wondering, the answer is "No, I don't have an ETA for when this will ship---it's an awful lot of very tricky work!")

[swift-parsing]: https://github.com/pointfreeco/swift-parsing
[tca]: https://github.com/pointfreeco/swift-composable-architecture
