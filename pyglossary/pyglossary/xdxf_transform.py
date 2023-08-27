from pyglossary import core
from pyglossary.core import rootDir
import logging
from io import BytesIO
from io import StringIO

log = logging.getLogger("pyglossary")


def xdxf_to_html_transformer():
	from lxml import etree
	from lxml.etree import tostring
	from os.path import join
	try:
		from lxml import etree as ET
	except ModuleNotFoundError as e:
		e.msg += f", run `{core.pip} install lxml` to install"
		raise e

	with open(join(rootDir, "pyglossary", "xdxf.xsl"), "r") as f:
		xslt_txt = f.read()

	xslt = ET.XML(xslt_txt)
	_transform = ET.XSLT(xslt)

	def transform(input_text: str) -> str:
		doc = etree.parse(StringIO(f"<ar>{input_text}</ar>"))
		result_tree = _transform(doc)
		text = tostring(result_tree, encoding="utf-8").decode("utf-8")
		text = text.replace("<br/> ", "<br/>")
		return text

	return transform


class XdxfTransformer(object):
	def __init__(self, encoding="utf-8"):
		self._encoding = encoding

	def tostring(self, elem: "lxml.etree.Element") -> str:
		from lxml import etree as ET
		return ET.tostring(
			elem,
			method="html",
			pretty_print=True,
		).decode("utf-8").strip()

	def hasPrevText(self, prev: "Union[None, str, lxml.etree.Element]"):
		if isinstance(prev, str):
			return True
		if prev is None:
			return False
		if prev.tag == "k":
			return False
		if prev.tag in (
			"dtrn", "def", "span", "co",
			"i", "b", "sub", "sup", "tt", "big", "small",
		):
			return True
		if prev.text:
			return True
		# print(prev)
		return False

	def writeString(
		self,
		hf: "lxml.etree.htmlfile",
		child: str,
		parent: "lxml.etree.Element",
		prev: "Union[None, str, lxml.etree.Element]",
	):
		from lxml import etree as ET
		hasPrev = self.hasPrevText(prev)
		trailNL = False
		if parent.tag in ("ar", "font"):
			if child.startswith("\n"):
				child = child.lstrip("\n")
				if hasPrev:
					hf.write(ET.Element("br"))
			elif child.endswith("\n"):
				child = child.rstrip("\n")
				trailNL = True
			if not hasPrev:
				child = child.lstrip()
		elif child.startswith("\n"):
			child = child.lstrip()
			hf.write(ET.Element("br"))

		for index, parag in enumerate(child.split("\n")):
			if index > 0:
				hf.write(ET.Element("br"))
			hf.write(parag)
		if trailNL:
			hf.write(ET.Element("br"))
		return

	def writeChild(
		self,
		hf: "lxml.etree.htmlfile",
		child: "Union[str, lxml.etree.Element]",
		parent: "lxml.etree.Element",
		prev: "Union[None, str, lxml.etree.Element]",
	):
		from lxml import etree as ET

		if isinstance(child, str):
			self.writeString(hf, child, parent, prev)
			return

		if child.tag == f"br":
			hf.write(ET.Element("br"))
			return

		if child.tag in ("i", "b", "sub", "sup", "tt", "big", "small"):
			with hf.element(child.tag):
				self.writeChildrenOf(hf, child)
				# if child.text is not None:
				#	hf.write(child.text.strip("\n"))
			return

		if child.tag == "blockquote":
			with hf.element("div", **{"class": "m"}):
				self.writeChildrenOf(hf, child)
			return

		if child.tag == "tr":
			hf.write("[")
			self.writeChildrenOf(hf, child)
			hf.write("]")
			return

		if child.tag in ("k", "ex"):
			with hf.element("span", **{"class": child.tag}):
				self.writeChildrenOf(hf, child)
			return

		if child.tag in ("pos", "abr"):
			with hf.element("span", **{"class": "abr"}):
				with hf.element("font", color="green"):
					with hf.element("i"):
						self.writeChildrenOf(hf, child)
			return

		if child.tag in ("dtrn", "co"):
			self.writeChildrenOf(hf, child)
			return

		if child.tag == "c":
			color = child.attrib.get("c", "green")
			with hf.element("font", color=color):
				self.writeChildrenOf(hf, child)
			return

		if child.tag == "kref":
			if not child.text:
				log.warning(f"kref with no text: {self.tostring(child)}")
				return
			with hf.element("a", **{
				"class": "kref",
				"href": f"bword://{child.attrib.get('k', child.text)}",
			}):
				hf.write(child.text)
			return

		if child.tag == "iref":
			if not child.text:
				log.warning(f"iref with no text: {self.tostring(child)}")
				return
			with hf.element("a", **{
				"class": "iref",
				"href": child.attrib.get("href", child.text),
			}):
				hf.write(child.text)
			return

		if child.tag == "rref":
			if not child.text:
				log.warning(f"rref with no text: {self.tostring(child)}")
				return

		if child.tag == "def":
			self.writeChildrenOf(hf, child)
			return

		log.warning(f"unknown tag {child.tag}")
		self.writeChildrenOf(hf, child)

	def writeChildrenOf(
		self,
		hf: "lxml.etree.htmlfile",
		elem: "lxml.etree.Element",
	):
		prev = None
		for child in elem.xpath("child::node()"):
			self.writeChild(hf, child, elem, prev)
			prev = child

	def transform(self, article: "lxml.etree.Element") -> str:
		from lxml import etree as ET
		encoding = self._encoding
		f = BytesIO()
		with ET.htmlfile(f, encoding="utf-8") as hf:
			with hf.element("div", **{"class": "article"}):
				self.writeChildrenOf(hf, article)

		text = f.getvalue().decode("utf-8")
		text = text.replace("<br>", "<br/>")  # for compatibility
		return text

	def transformByInnerString(self, articleInnerStr: str) -> str:
		from lxml import etree as ET
		return self.transform(
			ET.fromstring(f"<ar>{articleInnerStr}</ar>")
		)
