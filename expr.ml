type prim1 =
  | Add1
  | Sub1
  | Print
  | IsNum
  | IsBool
  | IsTuple

type prim2 =
  | Plus
  | Minus
  | Times
  | Less
  | Greater
  | Equal

type expr =
  | ELet of (string * expr) list * expr
  | EPrim1 of prim1 * expr
  | EPrim2 of prim2 * expr * expr
  | EApp of string * expr list
  | ETuple of expr list
  | EGetItem of expr * expr
  | EIf of expr * expr * expr
  | ENumber of int
  | EBool of bool
  | EId of string

type decl =
  | DFun of string * string list * expr

type program =
  | Program of decl list * expr


type immexpr =
  | ImmNumber of int
  | ImmBool of bool
  | ImmId of string

and cexpr =
  | CPrim1 of prim1 * immexpr
  | CPrim2 of prim2 * immexpr * immexpr
  | CApp of string * immexpr list
  | CTuple of immexpr list
  | CGetItem of immexpr * immexpr
  | CIf of immexpr * aexpr * aexpr
  | CImmExpr of immexpr

and aexpr =
  | ALet of string * cexpr * aexpr
  | ACExpr of cexpr

and adecl =
  | ADFun of string * string list * aexpr

and aprogram =
  | AProgram of adecl list * aexpr

