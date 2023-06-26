# Provenance

Swift reference implementation of the provenance marking system.

by Wolf McNally, wolf@wolfmcnally.com

## Introduction

Introducing a novel system called "Provenance Marks" for marking and verifying the provenance of creative or intellectual works, digital or physical. This system combines cryptography, pseudorandom number generation, and linguistic representation to produce a unique digital mark for each piece of work. Each mark, which can be represented as a sequence of natural language words, contains elements to verify the previous mark and commit to the content of the next one, forming a cryptographically-secured chain. This user-friendly method not only enhances security but also offers a simple solution for artists, institutions, and even larger commercial fields to protect their works against fraudulent claims and deep fakes.

Read the [whitepaper](WHITEPAPER.md).

## Installation

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/wolfmcnally/Provenance.git", from: "0.1.0")
]
```
