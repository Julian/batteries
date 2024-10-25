/-
Copyright (c) 2017 Robert Y. Lewis. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Robert Y. Lewis, Keeley Hoek, Mario Carneiro
-/

namespace Fin

/-- `min n m` as an element of `Fin (m + 1)` -/
def clamp (n m : Nat) : Fin (m + 1) := ⟨min n m, Nat.lt_succ_of_le (Nat.min_le_right ..)⟩

/-- `enum n` is the array of all elements of `Fin n` in order -/
def enum (n) : Array (Fin n) := Array.ofFn id

/-- `list n` is the list of all elements of `Fin n` in order -/
def list (n) : List (Fin n) := (enum n).toList

/--
Folds a monadic function over `Fin n` from left to right:
```
Fin.foldlM n f x₀ = do
  let x₁ ← f x₀ 0
  let x₂ ← f x₁ 1
  ...
  let xₙ ← f xₙ₋₁ (n-1)
  pure xₙ
```
-/
@[inline] def foldlM [Monad m] (n) (f : α → Fin n → m α) (init : α) : m α := loop init 0 where
  /--
  Inner loop for `Fin.foldlM`.
  ```
  Fin.foldlM.loop n f xᵢ i = do
    let xᵢ₊₁ ← f xᵢ i
    ...
    let xₙ ← f xₙ₋₁ (n-1)
    pure xₙ
  ```
  -/
  loop (x : α) (i : Nat) : m α := do
    if h : i < n then f x ⟨i, h⟩ >>= (loop · (i+1)) else pure x
  termination_by n - i

/--
Folds a monadic function over `Fin n` from right to left:
```
Fin.foldrM n f xₙ = do
  let xₙ₋₁ ← f (n-1) xₙ
  let xₙ₋₂ ← f (n-2) xₙ₋₁
  ...
  let x₀ ← f 0 x₁
  pure x₀
```
-/
@[inline] def foldrM [Monad m] (n) (f : Fin n → α → m α) (init : α) : m α :=
  loop ⟨n, Nat.le_refl n⟩ init where
  /--
  Inner loop for `Fin.foldrM`.
  ```
  Fin.foldrM.loop n f i xᵢ = do
    let xᵢ₋₁ ← f (i-1) xᵢ
    ...
    let x₁ ← f 1 x₂
    let x₀ ← f 0 x₁
    pure x₀
  ```
  -/
  loop : {i // i ≤ n} → α → m α
  | ⟨0, _⟩, x => pure x
  | ⟨i+1, h⟩, x => f ⟨i, h⟩ x >>= loop ⟨i, Nat.le_of_lt h⟩

/-- Sum of a list indexed by `Fin n`. -/
protected def sum [OfNat α (nat_lit 0)] [Add α] (x : Fin n → α) : α :=
  foldr n (x · + ·) 0

/-- Product of a list indexed by `Fin n`. -/
protected def prod [OfNat α (nat_lit 1)] [Mul α] (x : Fin n → α) : α :=
  foldr n (x · * ·) 1

/-- Count the number of true values of a decidable predicate on `Fin n`. -/
protected def count (P : Fin n → Prop) [DecidablePred P] : Nat :=
  Fin.sum (if P · then 1 else 0)

/-- Find the first true value of a decidable predicate on `Fin n`, if there is one. -/
protected def find? (P : Fin n → Prop) [DecidablePred P] : Option (Fin n) :=
  foldr n (fun i v => if P i then some i else v) none

/-- Custom recursor for `Fin (n+1)`. -/
def recZeroSuccOn {motive : Fin (n+1) → Sort _} (x : Fin (n+1))
    (zero : motive 0) (succ : (x : Fin n) → motive x.castSucc → motive x.succ) : motive x :=
  match x with
  | 0 => zero
  | ⟨x+1, hx⟩ =>
    let x : Fin n := ⟨x, Nat.lt_of_succ_lt_succ hx⟩
    succ x <| recZeroSuccOn x.castSucc zero succ

/-- Custom recursor for `Fin (n+1)`. -/
def casesZeroSuccOn {motive : Fin (n+1) → Sort _} (x : Fin (n+1))
    (zero : motive 0) (succ : (x : Fin n) → motive x.succ) : motive x :=
  match x with
  | 0 => zero
  | ⟨x+1, hx⟩ => succ ⟨x, Nat.lt_of_succ_lt_succ hx⟩
