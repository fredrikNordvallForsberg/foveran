{-# LANGUAGE TemplateHaskell, OverloadedStrings #-}

module Language.Foveran.Parsing.LexicalSpec where

import Language.Forvie.Lexing.Spec
import Language.Foveran.Parsing.Token

lexicalSpec :: LexicalSpecification (Action Token)
lexicalSpec = 
    [ ("assume",          Emit Assume)
    , (":",               Emit Colon)
    , (":=",              Emit ColonEquals)
    , (";",               Emit Semicolon)
    , ("=",               Emit Equals)
    , ("\\" .|. "\x03bb", Emit Lambda)
    , ("->" .|. "→",      Emit Arrow)
    , ("(",               Emit LParen)
    , (")",               Emit RParen)
    , ("“→”",             Emit QuoteArrow)
    , ("×",               Emit Times)
    , ("“×”",             Emit QuoteTimes)
    , ("+",               Emit Plus)
    , ("“+”",             Emit QuotePlus)
    , ("fst",             Emit Fst)
    , ("snd",             Emit Snd)
    , ("inl",             Emit Inl)
    , ("inr",             Emit Inr)
    , ("“K”",             Emit QuoteK)
    , ("µ",               Emit Mu)
    , ("construct",       Emit Construct)
    , ("induction",       Emit Induction)
    , ("elimD",           Emit ElimD)
    , ("()" .|. "⋄",      Emit UnitValue)
    , ("«",               Emit LDoubleAngle)
    , ("»",               Emit RDoubleAngle)
    , (",",               Emit Comma)
    , ("case",            Emit Case)
    , ("for",             Emit For)
    , (".",               Emit FullStop)
    , ("with",            Emit With)
    , ("{",               Emit LBrace)
    , ("}",               Emit RBrace)
    , ("Set",             Emit Set)
    , ("Empty" .|. "𝟘",   Emit EmptyType)
    , ("Unit" .|. "𝟙",    Emit UnitType)
    , ("elimEmpty",       Emit ElimEmpty)
    , ("“Id”",            Emit QuoteId)
    , ("Desc",            Emit Desc)
    , ("data",            Emit Data)
    , ("|",               Emit Pipe)
    , ("IDesc",           Emit IDesc)
    , ("'K",              Emit IDesc_K)
    , ("'Id",             Emit IDesc_Id)
    , ("'Pair",           Emit IDesc_Pair)
    , ("'Sg",             Emit IDesc_Sg)
    , ("'Pi",             Emit IDesc_Pi)
    , ("elimID",          Emit IDesc_Elim)
    , (tok (nameStartChar .&. complement (singleton '\x03bb')) .>>. zeroOrMore (tok nameChar),
                           Emit Ident)
    , (oneOrMore (tok digit),
                           Emit Number)
    , (oneOrMore (tok space),
                              Ignore Whitespace)
    , (("--" .|. "–") .>>. star (tok (complement (singleton '\n'))),
                          Ignore Comment)
    , ("{-"
       .>>.
       (star (tok anyChar) .&. complement (star (tok anyChar) .>>. "-}" .>>. star (tok anyChar)))
       .>>.
       "-}",              Ignore Comment)
    ]