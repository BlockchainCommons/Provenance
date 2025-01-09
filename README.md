# Provenance

<div style="display: flex;">
<img src="./art/provenance-mark-symbol-white.svg" width="100" style="float: left; margin-right: 10px">
<div><strong>PROVENANCE</strong><br/>Swift reference implementation of the provenance marking system.<br/>by Wolf McNally <a href="mailto:wolf@wolfmcnally.com">wolf@wolfmcnally.com</a></div>
</div>

## Introduction

Introducing a novel system called **Provenance Marks** for marking and verifying the provenance of creative or intellectual works, digital or physical. This system combines cryptography, pseudorandom number generation, and linguistic representation to produce a unique digital mark for each piece of work. Each mark, which can be represented as a sequence of natural language words, contains elements to verify the previous mark and commit to the content of the next one, forming a cryptographically-secured chain. This user-friendly method not only enhances security but also offers a simple solution for artists, institutions, and even larger commercial fields to protect their works against fraudulent claims and deep fakes.

Read the [white paper](https://github.com/BlockchainCommons/Research/blob/master/papers/bcr-2025-001-provenance-mark.md).

## License

* The Provenance code is available under the BSD 3-Clause license. See the [LICENSE file](LICENSE) for more info.

* The [Provenance Mark Symbol](./art) is available for use with the Provenance Marking system under the [Creative Commons Attribution-ShareAlike 4.0 International License](https://creativecommons.org/licenses/by-sa/4.0/).

## Installation

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/blockchaincommons/Provenance.git", from: "0.3.0")
]
```
