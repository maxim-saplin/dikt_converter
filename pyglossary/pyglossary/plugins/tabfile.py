# -*- coding: utf-8 -*-

from formats_common import *
from pyglossary.text_reader import TextGlossaryReader
from pyglossary.text_utils import (
	unescapeNTB,
	splitByBarUnescapeNTB,
)

enable = True
format = "Tabfile"
description = "Tabfile (.txt, .dic)"
extensions = (".txt", ".tab", ".tsv")
singleFile = True
optionsProp = {
	"encoding": EncodingOption(),
	"writeInfo": BoolOption(),
	"resources": BoolOption(),
	"file_size_approx": FileSizeOption(
		comment="split up by given approximate file size\nexamples: 100m, 1g",
	),
	"word_title": BoolOption(
		comment="add headwords title to begining of definition",
	),
}

# https://en.wikipedia.org/wiki/Tab-separated_values


class Reader(TextGlossaryReader):
	def __init__(self, glos: GlossaryType, hasInfo: bool = True):
		TextGlossaryReader.__init__(self, glos, hasInfo=hasInfo)
		self._resDir = ""
		self._resFileNames = []

	def open(self, filename: str) -> None:
		TextGlossaryReader.open(self, filename)
		resDir = f"{filename}_res"
		if isdir(resDir):
			self._resDir = resDir
			self._resFileNames = os.listdir(self._resDir)

	def __iter__(self) -> "Iterator[BaseEntry]":
		yield from TextGlossaryReader.__iter__(self)
		resDir = self._resDir
		for fname in self._resFileNames:
			with open(join(resDir, fname), "rb") as fromFile:
				yield self._glos.newDataEntry(
					fname,
					fromFile.read(),
				)

	def isInfoWord(self, word: str) -> bool:
		return word.startswith("#")

	def fixInfoWord(self, word: str) -> str:
		return word.lstrip("#")

	def nextPair(self) -> "Tuple[str, str]":
		if not self._file:
			raise StopIteration
		line = self.readline()
		if not line:
			raise StopIteration
		line = line.rstrip("\n")
		if not line:
			return
		###
		word, tab, defi = line.partition("\t")
		if not tab:
			log.error(
				f"Warning: line starting with {line[:10]!r} has no tab!"
			)
			return
		###
		if self._glos.getConfig("enable_alts", True):
			word = splitByBarUnescapeNTB(word)
			if len(word) == 1:
				word = word[0]
		else:
			word = unescapeNTB(word, bar=False)
		###
		defi = unescapeNTB(defi)
		###
		return word, defi


class Writer(object):
	_encoding: str = "utf-8"
	_writeInfo: bool = True
	_resources: bool = True
	_file_size_approx: int = 0
	_word_title: bool = False

	compressions = stdCompressions

	def __init__(self, glos: GlossaryType) -> None:
		self._glos = glos
		self._filename = None

	def open(
		self,
		filename: str,
	):
		self._filename = filename

	def finish(self):
		pass

	def write(self) -> "Generator[None, BaseEntry, None]":
		from pyglossary.text_writer import TextGlossaryWriter
		from pyglossary.text_utils import escapeNTB
		writer = TextGlossaryWriter(
			self._glos,
			entryFmt="{word}\t{defi}\n",
			writeInfo=self._writeInfo,
			outInfoKeysAliasDict=None,
		)
		writer._encoding = self._encoding
		writer._wordEscapeFunc = escapeNTB
		writer._defiEscapeFunc = escapeNTB
		writer._ext = ".txt"
		writer._resources = self._resources
		writer._file_size_approx = self._file_size_approx
		writer._word_title = self._word_title
		writer.open(self._filename)
		yield from writer.write()
		writer.finish()
