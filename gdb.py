import gdb
import re
import sys
import traceback

# Add the path to `debugger`
from os.path import dirname
sys.path.append(dirname(__file__))
import debugger

type_hash_regex = re.compile("^([A-Za-z0-9]*)_([A-Za-z0-9]*)_+([A-Za-z0-9]*)$")

def getNimRti(type_name):
  """ Return a ``gdb.Value`` object for the Nim Runtime Information of ``type_name``. """

  # Get static const TNimType variable. This should be available for
  # every non trivial Nim type.
  m = type_hash_regex.match(type_name)
  lookups = [
    "NTI" + m.group(2).lower() + "__" + m.group(3) + "_",
    "NTI" + "__" + m.group(3) + "_",
    "NTI" + m.group(2).replace("colon", "58").lower() + "__" + m.group(3) + "_"
    ]
  if m:
      for l in lookups:
        try:
          return gdb.parse_and_eval(l)
        except:
          pass
  None

def getNameFromNimRti(rti):
  """ Return name (or None) given a Nim RTI ``gdb.Value`` """
  try:
    # sometimes there isn't a name field -- example enums
    return rti['name'].string(encoding="utf-8", errors="ignore")
  except:
    return None

class NimTypeRecognizer:

  # object_type_pattern = re.compile("^(\w*):ObjectType$")

  def recognize(self, type_obj):
    # skip things we can't handle like functions
    if type_obj.code in [gdb.TYPE_CODE_FUNC, gdb.TYPE_CODE_VOID]:
      return None

    tname = None
    if type_obj.tag is not None:
      tname = type_obj.tag
    elif type_obj.name is not None:
      tname = type_obj.name

    # handle pointer types
    if not tname:
      target_type = type_obj
      if type_obj.code in [gdb.TYPE_CODE_PTR]:
        target_type = type_obj.target()

      if target_type.name:
        tname = debugger.debuggerTypeNameFromMangled(target_type.name)
        # visualize 'string' as non pointer type (unpack pointer type).
        # if target_type.name == "NimStringDesc":
        #   tname = target_type.name # could also just return 'string'
        # else:
        #   rti = getNimRti(target_type.name)
        #   if rti:
        #     return getNameFromNimRti(rti)

    if tname:
      result = debugger.debuggerTypeNameFromMangled(tname)
      if result:
        return result

      # rti = getNimRti(tname)
      # if rti:
      #   return getNameFromNimRti(rti)

    return None

class NimTypePrinter:
  """Nim type printer. One printer for all Nim types."""

  # enabling and disabling of type printers can be done with the
  # following gdb commands:
  #
  #   enable  type-printer NimTypePrinter
  #   disable type-printer NimTypePrinter
  # relevant docs: https://sourceware.org/gdb/onlinedocs/gdb/Type-Printing-API.html

  name = "NimTypePrinter"

  def __init__(self):
    self.enabled = True

  def instantiate(self):
    return NimTypeRecognizer()

class Nim(object):
  def __init__(self, val):
    self.enabled = True
    self.val = val
  def to_string(self):
    print(self.val.reference_value().format_string(address=True))
    # try:
    #   return gdb.parse_and_eval('debuggerRepr("%s", %d)' % (self.val.type.name, int(self.val.reference_value())))
    # except BaseException as e:
    #   print("error: {0}".format(e))
    return "error"
  def display_hint(self):
    return "hint" #gdb.parse_and_eval('debuggerHint("%s")' % self.val.type.name)

def register_nim_pretty_printers_for_object(objfile):
  nimMainSym = gdb.lookup_global_symbol("NimMain", gdb.SYMBOL_FUNCTIONS_DOMAIN)
  if nimMainSym and nimMainSym.symtab.objfile == objfile:
    gdb.types.register_type_printer(objfile, NimTypePrinter())
    objfile.pretty_printers = [Nim]

def new_object_handler(event):
  register_nim_pretty_printers_for_object(event.new_objfile)

debuggerInit = gdb.lookup_global_symbol("debuggerInit")
if debuggerInit:
  gdb.parse_and_eval("debuggerInit()")

for old_objfile in gdb.objfiles():
  register_nim_pretty_printers_for_object(old_objfile)

gdb.events.new_objfile.connect(new_object_handler)
