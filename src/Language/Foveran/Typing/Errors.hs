{-# LANGUAGE OverloadedStrings #-}

module Language.Foveran.Typing.Errors
    ( TypeError (..)
    , ppTypeError
    , ppTerm
    , ppType
    , DataDeclError (..)
    , ppDataDeclError
    )
    where

import           Text.PrettyPrint as PP
import           Language.Foveran.Syntax.Identifier (Ident, UsesIdentifiers, runNameGeneration)
import qualified Language.Foveran.Syntax.LocallyNameless as LN
import           Language.Foveran.Syntax.Checked (toDisplaySyntax)
import           Language.Foveran.Typing.Context
import           Language.Foveran.Typing.Conversion (Value, reifyTypeForDisplay, reifyForDisplay)
import           Language.Foveran.Parsing.PrettyPrinter

{------------------------------------------------------------------------------}
data TypeError
    -- Checking errors
    = SetLevelMismatch            Int Int
    | TermIsALambdaAbstraction    Value
    | TermIsAPairing              Value
    | TermIsASumIntroduction      Value
    | TermIsAUnitIntroduction     Value
    | TermIsADesc                 Value
    | TermIsAConstruct Value
    | TermIsASet                  Value
    | TermIsAGroupExpression      Value
    | TermIsAReturn               Value

    -- Checking errors for equality
    | ReflCanOnlyProduceHomogenousEquality Value Value
    | ReflCanOnlyProduceEquality  Value Value Value
    | TermIsAnEquality            Value

    -- Change of direction error
    | TypesNotEqual               Value Value

    -- Synthesis errors
    | UnknownIdentifier           Ident
    | ExpectingPiType             Value
    | ExpectingSumType            Value
    | ExpectingSet                Value
    | ExpectingEqualityType       Value
    | ExpectingHomogeneousEquality Value Value
    | ExpectingIDesc              Value
    | Proj1FromNonSigma           Value
    | Proj2FromNonSigma           Value
    | CallOnNonLabelledType       Value

    -- Term not well-formed
    | UnableToSynthesise          LN.TermPos

    | OtherError                  String -- FIXME: try to get rid of this

ppType :: UsesIdentifiers ctxt =>
          ctxt
       -> Value
       -> Doc
ppType ctxt v =
    ppPlain $ runNameGeneration ctxt $ toDisplaySyntax $ reifyTypeForDisplay v

ppTerm :: UsesIdentifiers ctxt =>
          ctxt
       -> Value
       -> Value
       -> Doc
ppTerm ctxt v vty =
    ppPlain $ runNameGeneration ctxt $ toDisplaySyntax $ reifyForDisplay vty v


ppTypeError :: UsesIdentifiers ctxt => ctxt -> TypeError -> Doc
ppTypeError ctxt (TermIsALambdaAbstraction ty)
    = "This term is a lambda-abstraction, but the context expects it to have type"
      $$ nest 4 (ppType ctxt ty)
ppTypeError ctxt (TermIsAPairing ty)
    = "This term is a pairing, but the context expects it to have type"
      $$ nest 4 (ppType ctxt ty)
ppTypeError ctxt (TermIsASumIntroduction ty)
    = "This term constructs a value of sum type, but the context expects it to have type"
      $$ nest 4 (ppType ctxt ty)
ppTypeError ctxt (TermIsAUnitIntroduction ty)
    = "This term constructs a value of the unit type, but the context expects it to have type"
      $$ nest 4 (ppType ctxt ty)
ppTypeError ctxt (TermIsADesc ty)
    = "This term constructs a datatype description, but the context expects it to have type"
      $$ nest 4 (ppType ctxt ty)
ppTypeError ctxt (TermIsAConstruct ty)
    = "This term constructs a value of an inductive type, but the context expects it to have type"
      $$ nest 4 (ppType ctxt ty)
ppTypeError ctxt (TermIsASet v)
    = "This term is a set, but the context was expecting a term of type"
      $$ nest 4 (ppType ctxt v)
ppTypeError ctxt (TermIsAGroupExpression v)
    = "This term is a group expression, but the context was expecting a term of type" 
      $$ nest 4 (ppType ctxt v)
ppTypeError ctxt (TermIsAnEquality ty)
    = "This term produces a value of equality type, but the context was expecting a term of type"
      $$ nest 4 (ppType ctxt ty)
ppTypeError ctxt (SetLevelMismatch l1 l2)
    = "Set level problem: 'Set" <+> int l1 PP.<> "' does not have type 'Set" <+> int l2 PP.<> "'"
ppTypeError ctxt (TermIsAReturn ty)
    = "This term produces values of a labelled type, but the context was expecting a term of type"
      $$ nest 4 (ppType ctxt ty)

ppTypeError ctxt (ReflCanOnlyProduceHomogenousEquality tyA tyB)
    = "'refl' can only produce homogenous equalities; types given:"
      $$ nest 4 (ppType ctxt tyA)
      $$ "and"
      $$ nest 4 (ppType ctxt tyB)
ppTypeError ctxt (ReflCanOnlyProduceEquality ty a b)
    = "Type checking 'refl', but terms"
      $$ nest 4 (ppTerm ctxt a ty)
      $$ "and"
      $$ nest 4 (ppTerm ctxt b ty)
      $$ "are not equal."

-- Synthesis errors
ppTypeError ctxt (UnknownIdentifier nm)
    = "Unknown identifier" <+> "“" PP.<> ppIdent nm PP.<> "”"
ppTypeError ctxt (ExpectingPiType ty)
    = "Application of non function. Term has type"
      $$ nest 4 (ppType ctxt ty)
ppTypeError ctxt (ExpectingSumType ty)
    = "Case on value of non-sum type. Term has type"
      $$ nest 4 (ppType ctxt ty)
ppTypeError ctxt (ExpectingSet ty)
    = "Expecting a term of type 'Set i', for some level i, but term has type"
      $$ nest 4 (ppType ctxt ty)
ppTypeError ctxt (Proj1FromNonSigma ty)
    = "First projection from non Sigma-type. Actual type is"
      $$ nest 4 (ppType ctxt ty)
ppTypeError ctxt (Proj2FromNonSigma ty)
    = "Second projection from non Sigma-type. Actual type is"
      $$ nest 4 (ppType ctxt ty)
ppTypeError ctxt (ExpectingEqualityType ty)
    = "Expecting term to have an equality type, but type is"
      $$ nest 4 (ppType ctxt ty)
ppTypeError ctxt (ExpectingHomogeneousEquality ty1 ty2)
    = "Equality elimination can only handle elimination of homogeneous equalities, types involved are:"
      $$ nest 4 (ppType ctxt ty1)
      $$ "and"
      $$ nest 4 (ppType ctxt ty2)
ppTypeError ctxt (ExpectingIDesc ty)
    = "Expecting term to have indexed description type, but type is"
      $$ nest 4 (ppType ctxt ty)
ppTypeError ctxt (CallOnNonLabelledType ty)
    = "Call invocation on a non-labelled type, type is:"
      $$ nest 4 (ppType ctxt ty)

ppTypeError ctxt (UnableToSynthesise t)
    = "Unable to synthesise type for this term: " PP.<> text (show t)
ppTypeError ctxt (TypesNotEqual ty1 ty2)
    = "Expecting term to have type "
      $$ nest 4 (ppType ctxt ty1)
      $$ "but term has type"
      $$ nest 4 (ppType ctxt ty2)

ppTypeError ctxt (OtherError msg)
    = text msg

{------------------------------------------------------------------------------}
data DataDeclError
    = DuplicateParameterName      Ident
    | DuplicateConstructorName    Ident
    | ShadowingDatatypeName
    | ShadowingParameterName
    | ConstructorTypesMustEndWithNameOfDatatype Ident Ident
    | NonMatchingParameterArgument Ident Ident
    | IllFormedArgument            Ident
    | TooManyArgumentsForDatatype
    | NotEnoughArgumentsForDatatype

ppDataDeclError :: DataDeclError -> Doc
ppDataDeclError (DuplicateConstructorName ident)
    = "Duplicate constructor name: '" PP.<> ppIdent ident PP.<> "'"
ppDataDeclError (DuplicateParameterName ident)
    = "Duplicate parameter name: '" PP.<> ppIdent ident PP.<> "'"
ppDataDeclError (ShadowingDatatypeName)
    = "Shadowing of the data type's name in constructor definition"
ppDataDeclError (ShadowingParameterName)
    = "Shadowing of a parameter name in constructor definition"
ppDataDeclError (ConstructorTypesMustEndWithNameOfDatatype givenNm expectedNm)
    = "Constructor types must end with the name of the datatype being defined: '" PP.<> ppIdent expectedNm PP.<> "', not '" PP.<> ppIdent givenNm PP.<> "'"
ppDataDeclError (NonMatchingParameterArgument givenNm expectedNm)
    = "Parameter argument has incorrect name: should be '" PP.<> ppIdent expectedNm PP.<> "', not '" PP.<> ppIdent givenNm PP.<> "'"
ppDataDeclError (IllFormedArgument expectedNm)
    = "Ill-formed parameter argument: should be '" PP.<> ppIdent expectedNm PP.<> "'"
ppDataDeclError (TooManyArgumentsForDatatype)
    = "Too many arguments for data type in constructor declaration"
ppDataDeclError (NotEnoughArgumentsForDatatype)
    = "Not enough arguments for data type in constructor declaration"
