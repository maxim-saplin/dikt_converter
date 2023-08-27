# -*- coding: utf-8 -*-

from formats_common import *

enable = True
format = "Json"
description = "JSON (.json)"
extensions = (".json",)
singleFile = True
optionsProp = {
	"encoding": EncodingOption(),
	"writeInfo": BoolOption(),
	"resources": BoolOption(),
	"word_title": BoolOption(
		comment="add headwords title to begining of definition",
	),
}


class Writer(object):
	_encoding: str = "utf-8"
	_writeInfo: bool = True
	_resources: bool = True
	_word_title: bool = False

	compressions = stdCompressions

	def __init__(self, glos: GlossaryType) -> None:
		self._glos = glos
		self._filename = None

	def open(self, filename: str):
		self._filename = filename

	def finish(self):
		self._filename = None

	def write(self) -> "Generator[None, BaseEntry, None]":
		from json import dumps
		from pyglossary.text_writer import writeTxt

		glos = self._glos
		encoding = self._encoding
		writeInfo = self._writeInfo
		resources = self._resources

		ascii = encoding == "ascii"

		def escape(st):
			#remove styling from HTML tags
			st2 = re.sub(r' style="[^"]*"', '', st) 
			st2 = re.sub(r' class="[^"]*"', '', st2) 
			st2 = re.sub(r'<font [^>]*>', '', st2) 
			st2 = re.sub(r'</font>', '', st2) 
			st2 = re.sub(r'\n', '', st2) 
			st2 = re.sub(r'<div></div>', '', st2) 
			st2 = re.sub(r'<span></span>', '', st2) 
			#fix russina dictionary issues, such as hypenation in word (e.g. абб{[']}а{[/']}т)
			st2 = re.sub(r"\{\['\]\}", "", st2)
			st2 = re.sub(r"\{\[/'\]\}", "", st2) 
			return dumps(st2, ensure_ascii=ascii)


		yield from writeTxt(
			glos,
			entryFmt="\t{word}: {defi},\n",
			filename=self._filename,
			encoding=encoding,
			writeInfo=writeInfo,
			wordEscapeFunc=escape,
			defiEscapeFunc=escape,
			ext=".json",
			head="{\n",
			tail='\t"": ""\n}',
			resources=resources,
			word_title=self._word_title,
		)
