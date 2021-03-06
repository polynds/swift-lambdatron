//
//  TestEvaluating.swift
//  Lambdatron
//
//  Created by Austin Zheng on 1/19/15.
//  Copyright (c) 2015 Austin Zheng. All rights reserved.
//

import Foundation

/// Test the way functions are evaluated.
class TestFunctionEvaluation : InterpreterTest {

  override func setUp() {
    super.setUp()
    clearOutputBuffer()
    interpreter.writeOutput = writeToBuffer
  }

  override func tearDown() {
    // Reset the interpreter
    clearOutputBuffer()
    interpreter.writeOutput = print
  }

  /// A function should properly return the value of the last form in its body.
  func testFunctionReturnValue() {
    runCode("(def testFunc (fn [] (.+ 1 2)))")
    expectThat("(testFunc)", shouldEvalTo: .IntAtom(3))
  }

  /// A function should run its body forms in order and return the value of the last one.
  func testFunctionBodyEvaluation() {
    runCode("(def testFunc (fn [] (.print \"first\") (.print \"second\") (.print \"third\") 1.2345))")
    expectThat("(testFunc)", shouldEvalTo: .FloatAtom(1.2345))
    expectOutputBuffer(toBe: "firstsecondthird")
  }

  /// A function should properly run recursively when referred to by the name within the 'fn' definition.
  func testFunctionRecursion() {
    // This lambda just counts down from a starting value and returns 'true' when done.
    expectThat("((fn rec [a] (if (.= a 0) (do (.print \"done\") true) (do (.print a) (rec (.- a 1))))) 15)",
      shouldEvalTo: .BoolAtom(true))
    expectOutputBuffer(toBe: "151413121110987654321done")
  }

  /// Mutually recursive functions should call each other properly.
  func testMutualRecursion() {
    runCode("(def f1 (fn [a] (if (.= a 0) (.print \"f1-done\") (do (.print \"f1\" a \" \") (f2 (.- a 1))))))")
    runCode("(def f2 (fn [a] (if (.= a 0) (.print \"f2-done\") (do (.print \"f2\" a \" \") (f3 (.- a 1))))))")
    runCode("(def f3 (fn [a] (if (.= a 0) (.print \"f3-done\") (do (.print \"f3\" a \" \") (f1 (.- a 1))))))")
    runCode("(f1 10)")
    expectOutputBuffer(toBe: "f1 10  f2 9  f3 8  f1 7  f2 6  f3 5  f1 4  f2 3  f3 2  f1 1  f2-done")
  }

  /// A function with multiple arities should pick the appropriate fixed arity, if appropriate.
  func testFixedArityMultiFunction() {
    runCode("(def testFunc (fn ([a b c] (.print \"3 args:\" a b c)) ([a b] (.print \"2 args:\" a b)) ([a] (.print \"1 arg:\" a))))")
    runCode("(testFunc 1 2 3)")
    expectOutputBuffer(toBe: "3 args: 1 2 3")
    // Try 2
    clearOutputBuffer()
    runCode("(testFunc 12345)")
    expectOutputBuffer(toBe: "1 arg: 12345")
    // Try 3
    clearOutputBuffer()
    runCode("(testFunc 9 7)")
    expectOutputBuffer(toBe: "2 args: 9 7")
  }

  /// A function with multiple arities should pick the appropriate variadic body, if appropriate.
  func testVariadicMultiFunction() {
    runCode("(def testFunc (fn ([a b] (.print \"2 args:\" a b)) ([a b & c] (.print \"varargs:\" a b c))))")
    runCode("(testFunc 10 20)")
    expectOutputBuffer(toBe: "2 args: 10 20")
    // Try 2
    clearOutputBuffer()
    runCode("(testFunc 9 97 998)")
    expectOutputBuffer(toBe: "varargs: 9 97 (998)")
    // Try 3
    clearOutputBuffer()
    runCode("(testFunc -1 0 14 15)")
    expectOutputBuffer(toBe: "varargs: -1 0 (14 15)")
  }

  /// A function's output should not be further evaluated.
  func testFunctionOutputEvaluation() {
    runCode("(def testFunc (fn [] (.list .+ 500 200)))")
    expectThat("(testFunc)",
      shouldEvalTo: .List(Cons(.BuiltInFunction(.Plus),
        next: Cons(.IntAtom(500), next: Cons(.IntAtom(200))))))
  }

  /// A function's arguments should be evaluated by the time the function sees them.
  func testParamEvaluation() {
    // Define a function
    runCode("(def testFunc (fn [a b] (.print a) (.print \", \") (.print b) true))")
    expectThat("(testFunc (.+ 1 2) (.+ 3 4))", shouldEvalTo: .BoolAtom(true))
    expectOutputBuffer(toBe: "3, 7")
  }

  /// A function's arguments should be evaluated in order, from left to right.
  func testParamEvaluationOrder() {
    // Define a function that takes 4 args and does nothing
    runCode("(def testFunc (fn [a b c d] nil))")
    expectThat("(testFunc (.print \"arg1\") (.print \"arg2\") (.print \"arg3\") (.print \"arg4\"))",
      shouldEvalTo: .Nil)
    expectOutputBuffer(toBe: "arg1arg2arg3arg4")
  }

  /// Vars and unshadowed let bindings should be available within a function body.
  func testBindingHierarchy() {
    runCode("(def a 187)")
    runCode("(let [b 51] (def testFunc (fn [c] (.+ (.+ a b) c))))")
    expectThat("(testFunc 91200)", shouldEvalTo: .IntAtom(91438))
  }

  /// A function's arguments should shadow any vars or let bindings.
  func testBindingShadowing() {
    runCode("(def a 187)")
    runCode("(let [b 51] (def testFunc (fn [a b c] (.+ (.+ a b) c))))")
    expectThat("(testFunc 100 201 512)", shouldEvalTo: .IntAtom(813))
  }

  /// A function should not capture a var's value at creation time.
  func testFunctionVarCapture() {
    // Define a function that returns a var
    runCode("(def testFunc (fn [] a))")
    runCode("(def a 500)")
    expectThat("(testFunc)", shouldEvalTo: .IntAtom(500))
    runCode("(def a false)")
    expectThat("(testFunc)", shouldEvalTo: .BoolAtom(false))
  }
}

/// Test the way macros are evaluated.
class TestMacroEvaluation : InterpreterTest {

  override func setUp() {
    super.setUp()
    clearOutputBuffer()
    interpreter.writeOutput = writeToBuffer
  }

  override func tearDown() {
    // Reset the interpreter
    clearOutputBuffer()
    interpreter.writeOutput = print
  }

  /// A macro should properly return the value of the last form in its body for evaluation.
  func testMacroReturnValue() {
    runCode("(defmacro testMacro [] 3)")
    expectThat("(testMacro)", shouldEvalTo: .IntAtom(3))
  }

  /// A macro should run its body forms in order and return the value of the last one.
  func testMacroBodyEvaluation() {
    runCode("(defmacro testMacro [] (.print \"first\") (.print \"second\") (.print \"third\") 1.2345)")
    expectThat("(testMacro)", shouldEvalTo: .FloatAtom(1.2345))
    expectOutputBuffer(toBe: "firstsecondthird")
  }

  /// A macro's output form should be automatically evaluated to produce a value.
  func testMacroOutputEvaluation() {
    runCode("(defmacro testMacro [] (.list .+ 500 200))")
    expectThat("(testMacro)", shouldEvalTo: .IntAtom(700))
  }

  /// A macro's output form should be evaluated with regards to both argument and external bindings.
  func testMacroOutputWithArgs() {
    runCode("(def a 11)")
    runCode("(defmacro testMacro [b] (.list .+ a b))")
    expectThat("(testMacro 12)", shouldEvalTo: .IntAtom(23))
  }

  /// A macro's parameters should be passed to the macro without being evaluated or otherwise touched.
  func testMacroParameters() {
    // Define a macro that takes 2 parameters
    runCode("(defmacro testMacro [a b] (.print a) (.print b) nil)")
    expectThat("(testMacro (+ 1 2) [(+ 3 4) 5])", shouldEvalTo: .Nil)
    expectOutputBuffer(toBe: "(+ 1 2)[(+ 3 4) 5]")
  }

  /// A macro should not evaluate its parameters if not explicitly asked to do so.
  func testMacroUntouchedParam() {
    // Note that only either 'then' or 'else' can ever be evaluated.
    runCode("(defmacro testMacro [pred then else] (if pred then else))")
    expectThat("(testMacro true (do (.print \"good\") 123) (.print \"bad\"))", shouldEvalTo: .IntAtom(123))
    expectOutputBuffer(toBe: "good")
  }

  /// Vars and unshadowed let bindings should be available within a macro body.
  func testBindingHierarchy() {
    runCode("(def a 187)")
    runCode("(let [b 51] (defmacro testMacro [c] (.+ (.+ a b) c)))")
    expectThat("(testMacro 91200)", shouldEvalTo: .IntAtom(91438))
  }

  /// A macro's arguments should shadow any vars or let bindings.
  func testBindingShadowing() {
    runCode("(def a 187)")
    runCode("(let [b 51] (defmacro testMacro [a b c] (.+ (.+ a b) c)))")
    expectThat("(testMacro 100 201 512)", shouldEvalTo: .IntAtom(813))
  }

  /// A macro should not capture a var's value at creation time.
  func testMacroVarCapture() {
    // Define a function that returns a var
    runCode("(defmacro testMacro [] a)")
    runCode("(def a 500)")
    expectThat("(testMacro)", shouldEvalTo: .IntAtom(500))
    runCode("(def a false)")
    expectThat("(testMacro)", shouldEvalTo: .BoolAtom(false))
  }

  /// If a symbol in a macro is not part of the lexical context, lookup at expansion time should evaluate to a var.
  func testMacroSymbolCapture() {
    runCode("(def b \"hello\")")
    // note the lexical context: no definition for 'b'
    runCode("(defmacro testMacro [a] (.list .+ a b))")
    runCode("(def b 125)")
    // testMacro, when run, must resort to getting the var named 'b'
    expectThat("(testMacro 6)", shouldEvalTo: .IntAtom(131))
    runCode("(def b 918)")
    expectThat("(testMacro 6)", shouldEvalTo: .IntAtom(924))
  }

  /// A macro should capture its lexical context and bind valid symbols to items in that context as necessary.
  func testMacroBindingCapture() {
    // This unit test is actually similar to 'testBindingShadowing' above, but more explicit.
    // note the lexical context: definition for 'b'
    runCode("(let [b 51] (defmacro testMacro [a] (.list .+ a b)))")
    runCode("(def b 125)")
    // testMacro, when run, always resolves 'b' to its binding when the macro was defined
    expectThat("(testMacro 6)", shouldEvalTo: .IntAtom(57))
    runCode("(def b 918)")
    expectThat("(testMacro 6)", shouldEvalTo: .IntAtom(57))
  }
}
