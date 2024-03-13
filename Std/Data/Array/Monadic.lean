/-
Copyright (c) 2021 Mario Carneiro. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

Authors: Mario Carneiro, Gabriel Ebner
-/
import Std.Classes.SatisfiesM

/-!
# Results about monadic operations on `Array`.
-/

namespace Array


theorem SatisfiesM_anyM [Monad m] [LawfulMonad m] (p : α → m Bool) (as : Array α) (start stop)
    (hstart : start ≤ min stop as.size) (tru : Prop) (fal : Nat → Prop) (h0 : fal start)
    (hp : ∀ i : Fin as.size, i.1 < stop → fal i.1 →
      SatisfiesM (bif · then tru else fal (i + 1)) (p as[i])) :
    SatisfiesM
      (fun res => bif res then tru else fal (min stop as.size))
      (anyM p as start stop) := by
  let rec go {stop j} (hj' : j ≤ stop) (hstop : stop ≤ as.size) (h0 : fal j)
    (hp : ∀ i : Fin as.size, i.1 < stop → fal i.1 →
      SatisfiesM (bif · then tru else fal (i + 1)) (p as[i])) :
    SatisfiesM
      (fun res => bif res then tru else fal stop)
      (anyM.loop p as stop hstop j) := by
    unfold anyM.loop; split
    · next hj =>
      exact (hp ⟨j, Nat.lt_of_lt_of_le hj hstop⟩ hj h0).bind fun
        | true, h => .pure h
        | false, h => go hj hstop h hp
    · next hj => exact .pure <| Nat.le_antisymm hj' (Nat.ge_of_not_lt hj) ▸ h0
    termination_by stop - j
  simp only [Array.anyM_eq_anyM_loop]
  exact go hstart _ h0 fun i hi => hp i <| Nat.lt_of_lt_of_le hi <| Nat.min_le_left ..

theorem SatisfiesM_anyM_iff_exists [Monad m] [LawfulMonad m]
    (p : α → m Bool) (as : Array α) (start stop) (q : Fin as.size → Prop)
    (hp : ∀ i : Fin as.size, start ≤ i.1 → i.1 < stop → SatisfiesM (· = true ↔ q i) (p as[i])) :
    SatisfiesM
      (fun res => res = true ↔ ∃ i : Fin as.size, start ≤ i.1 ∧ i.1 < stop ∧ q i)
      (anyM p as start stop) := by
  cases Nat.le_total start (min stop as.size) with
  | inl hstart =>
    refine (SatisfiesM_anyM _ _ _ _ hstart
      (fal := fun j => start ≤ j ∧ ¬ ∃ i : Fin as.size, start ≤ i.1 ∧ i.1 < j ∧ q i)
      (tru := ∃ i : Fin as.size, start ≤ i.1 ∧ i.1 < stop ∧ q i) ?_ ?_).imp ?_
    · exact ⟨Nat.le_refl _, fun ⟨i, h₁, h₂, _⟩ => (Nat.not_le_of_gt h₂ h₁).elim⟩
    · refine fun i h₂ ⟨h₁, h₃⟩ => (hp _ h₁ h₂).imp fun hq => ?_
      unfold cond; split <;> simp at hq
      · exact ⟨_, h₁, h₂, hq⟩
      · refine ⟨Nat.le_succ_of_le h₁, h₃.imp fun ⟨j, h₃, h₄, h₅⟩ => ⟨j, h₃, ?_, h₅⟩⟩
        refine Nat.lt_of_le_of_ne (Nat.le_of_lt_succ h₄) fun e => hq (Fin.eq_of_val_eq e ▸ h₅)
    · intro
      | true, h => simp only [true_iff]; exact h
      | false, h =>
        simp only [false_iff]
        exact h.2.imp fun ⟨j, h₁, h₂, hq⟩ => ⟨j, h₁, Nat.lt_min.2 ⟨h₂, j.2⟩, hq⟩
  | inr hstart =>
    rw [anyM_stop_le_start (h := hstart)]
    refine .pure ?_; simp; intro j h₁ h₂
    cases Nat.not_lt.2 (Nat.le_trans hstart h₁) (Nat.lt_min.2 ⟨h₂, j.2⟩)

theorem SatisfiesM_foldrM [Monad m] [LawfulMonad m]
    {as : Array α} (motive : Nat → β → Prop)
    {init : β} (h0 : motive as.size init) {f : α → β → m β}
    (hf : ∀ i : Fin as.size, ∀ b, motive (i.1 + 1) b → SatisfiesM (motive i.1) (f as[i] b)) :
    SatisfiesM (motive 0) (as.foldrM f init) := by
  let rec go {i b} (hi : i ≤ as.size) (H : motive i b) :
    SatisfiesM (motive 0) (foldrM.fold f as 0 i hi b) := by
    unfold foldrM.fold; simp; split
    · next hi => exact .pure (hi ▸ H)
    · next hi =>
      split; {simp at hi}
      · next i hi' =>
        exact (hf ⟨i, hi'⟩ b H).bind fun _ => go _
  simp [foldrM]; split; {exact go _ h0}
  · next h => exact .pure (Nat.eq_zero_of_not_pos h ▸ h0)

theorem SatisfiesM_mapIdxM [Monad m] [LawfulMonad m] (as : Array α) (f : Fin as.size → α → m β)
    (motive : Nat → Prop) (h0 : motive 0)
    (p : Fin as.size → β → Prop)
    (hs : ∀ i, motive i.1 → SatisfiesM (p i · ∧ motive (i + 1)) (f i as[i])) :
    SatisfiesM
      (fun arr => motive as.size ∧ ∃ eq : arr.size = as.size, ∀ i h, p ⟨i, h⟩ (arr[i]'(eq ▸ h)))
      (Array.mapIdxM as f) := by
  let rec go {bs i j h} (h₁ : j = bs.size) (h₂ : ∀ i h h', p ⟨i, h⟩ bs[i]) (hm : motive j) :
    SatisfiesM
      (fun arr => motive as.size ∧ ∃ eq : arr.size = as.size, ∀ i h, p ⟨i, h⟩ (arr[i]'(eq ▸ h)))
      (Array.mapIdxM.map as f i j h bs) := by
    induction i generalizing j bs with simp [mapIdxM.map]
    | zero =>
      have := (Nat.zero_add _).symm.trans h
      exact .pure ⟨this ▸ hm, h₁ ▸ this, fun _ _ => h₂ ..⟩
    | succ i ih =>
      refine (hs _ (by exact hm)).bind fun b hb => ih (by simp [h₁]) (fun i hi hi' => ?_) hb.2
      simp at hi'; simp [get_push]; split
      · next h => exact h₂ _ _ h
      · next h => cases h₁.symm ▸ (Nat.le_or_eq_of_le_succ hi').resolve_left h; exact hb.1
  simp [mapIdxM]; exact go rfl nofun h0

theorem mapIdx_induction (as : Array α) (f : Fin as.size → α → β)
    (motive : Nat → Prop) (h0 : motive 0)
    (p : Fin as.size → β → Prop)
    (hs : ∀ i, motive i.1 → p i (f i as[i]) ∧ motive (i + 1)) :
    motive as.size ∧ ∃ eq : (Array.mapIdx as f).size = as.size,
      ∀ i h, p ⟨i, h⟩ ((Array.mapIdx as f)[i]'(eq ▸ h)) := by
  have := SatisfiesM_mapIdxM (m := Id) (as := as) (f := f) motive h0
  simp [SatisfiesM_Id_eq] at this
  exact this _ hs

theorem mapIdx_spec (as : Array α) (f : Fin as.size → α → β)
    (p : Fin as.size → β → Prop) (hs : ∀ i, p i (f i as[i])) :
    ∃ eq : (Array.mapIdx as f).size = as.size,
      ∀ i h, p ⟨i, h⟩ ((Array.mapIdx as f)[i]'(eq ▸ h)) :=
  (mapIdx_induction _ _ (fun _ => True) trivial p fun _ _ => ⟨hs .., trivial⟩).2

@[simp] theorem size_mapIdx (a : Array α) (f : Fin a.size → α → β) : (a.mapIdx f).size = a.size :=
  (mapIdx_spec (p := fun _ _ => True) (hs := fun _ => trivial)).1

@[simp] theorem size_zipWithIndex (as : Array α) : as.zipWithIndex.size = as.size :=
  Array.size_mapIdx _ _

@[simp] theorem getElem_mapIdx (a : Array α) (f : Fin a.size → α → β) (i : Nat) (h) :
    haveI : i < a.size := by simp_all
    (a.mapIdx f)[i]'h = f ⟨i, this⟩ a[i] :=
  (mapIdx_spec _ _ (fun i b => b = f i a[i]) fun _ => rfl).2 i _

theorem size_modifyM [Monad m] [LawfulMonad m] (a : Array α) (i : Nat) (f : α → m α) :
    SatisfiesM (·.size = a.size) (a.modifyM i f) := by
  unfold modifyM; split
  · exact .bind_pre <| .of_true fun _ => .pure <| by simp only [size_set]
  · exact .pure rfl

@[simp] theorem size_modify (a : Array α) (i : Nat) (f : α → α) : (a.modify i f).size = a.size := by
  rw [← SatisfiesM_Id_eq (p := (·.size = a.size)) (x := a.modify i f)]
  apply size_modifyM
