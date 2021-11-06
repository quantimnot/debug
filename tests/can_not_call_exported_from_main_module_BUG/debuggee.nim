type
  MyEnum = enum
    meOne,
    meTwo,
    meThree,
    meFour,
  MyType = object
    a*: int
    b*: string
  MyVariant = ref object
    id*: int
    case kind*: MyEnum
    of meOne: mInt*: int
    of meTwo, meThree: discard
    of meFour:
      moInt*: int
      babies*: seq[MyVariant]
    after: float

proc main =
  # var x: MyVariant
  let tbool = true
  let tint = 0
  let tint8 = 0.int8
  let tchar = 'a'
  # let s = "test"
  echo tchar

main()
