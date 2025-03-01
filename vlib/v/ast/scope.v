// Copyright (c) 2019-2021 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module ast

[heap]
pub struct Scope {
pub mut:
	// mut:
	objects              map[string]ScopeObject
	struct_fields        map[string]ScopeStructField
	parent               &Scope
	detached_from_parent bool
	children             []&Scope
	start_pos            int
	end_pos              int
}

[unsafe]
pub fn (s &Scope) free() {
	unsafe {
		s.objects.free()
		s.struct_fields.free()
		for child in s.children {
			child.free()
		}
		s.children.free()
	}
}

/*
pub fn new_scope(parent &Scope, start_pos int) &Scope {
	return &Scope{
		parent: parent
		start_pos: start_pos
	}
}
*/

fn (s &Scope) dont_lookup_parent() bool {
	return isnil(s.parent) || s.detached_from_parent
}

pub fn (s &Scope) find_with_scope(name string) ?(ScopeObject, &Scope) {
	mut sc := s
	for {
		if name in sc.objects {
			return sc.objects[name], sc
		}
		if sc.dont_lookup_parent() {
			break
		}
		sc = sc.parent
	}
	return none
}

pub fn (s &Scope) find(name string) ?ScopeObject {
	for sc := s; true; sc = sc.parent {
		if name in sc.objects {
			return sc.objects[name]
		}
		if sc.dont_lookup_parent() {
			break
		}
	}
	return none
}

// selector_expr:  name.field_name
pub fn (s &Scope) find_struct_field(name string, struct_type Type, field_name string) ?ScopeStructField {
	for sc := s; true; sc = sc.parent {
		if field := sc.struct_fields[name] {
			if field.struct_type == struct_type && field.name == field_name {
				return field
			}
		}
		if sc.dont_lookup_parent() {
			break
		}
	}
	return none
}

pub fn (s &Scope) is_known(name string) bool {
	if _ := s.find(name) {
		return true
	} else {
	}
	return false
}

pub fn (s &Scope) find_var(name string) ?&Var {
	if obj := s.find(name) {
		match obj {
			Var { return &obj }
			else {}
		}
	}
	return none
}

pub fn (s &Scope) find_global(name string) ?&GlobalField {
	if obj := s.find(name) {
		match obj {
			GlobalField { return &obj }
			else {}
		}
	}
	return none
}

pub fn (s &Scope) find_const(name string) ?&ConstField {
	if obj := s.find(name) {
		match obj {
			ConstField { return &obj }
			else {}
		}
	}
	return none
}

pub fn (s &Scope) known_var(name string) bool {
	if _ := s.find_var(name) {
		return true
	}
	return false
}

pub fn (mut s Scope) update_var_type(name string, typ Type) {
	s.end_pos = s.end_pos // TODO mut bug
	mut obj := s.objects[name]
	match mut obj {
		Var {
			if obj.typ == typ {
				return
			}
			obj.typ = typ
		}
		else {}
	}
}

// selector_expr:  name.field_name
pub fn (mut s Scope) register_struct_field(name string, field ScopeStructField) {
	if f := s.struct_fields[name] {
		if f.struct_type == field.struct_type && f.name == field.name {
			return
		}
	}
	s.struct_fields[name] = field
}

pub fn (mut s Scope) register(obj ScopeObject) {
	name := if obj is ConstField {
		obj.name
	} else if obj is GlobalField {
		obj.name
	} else {
		(obj as Var).name
	}
	if name == '_' {
		return
	}
	if name in s.objects {
		// println('existing obect: $name')
		return
	}
	s.objects[name] = obj
}

pub fn (s &Scope) outermost() &Scope {
	mut sc := s
	for !sc.dont_lookup_parent() {
		sc = sc.parent
	}
	return sc
}

// returns the innermost scope containing pos
// pub fn (s &Scope) innermost(pos int) ?&Scope {
pub fn (s &Scope) innermost(pos int) &Scope {
	if s.contains(pos) {
		// binary search
		mut first := 0
		mut last := s.children.len - 1
		mut middle := last / 2
		for first <= last {
			// println('FIRST: $first, LAST: $last, LEN: $s.children.len-1')
			s1 := s.children[middle]
			if s1.end_pos < pos {
				first = middle + 1
			} else if s1.contains(pos) {
				return s1.innermost(pos)
			} else {
				last = middle - 1
			}
			middle = (first + last) / 2
			if first > last {
				break
			}
		}
		return s
	}
	// return none
	return s
}

[inline]
pub fn (s &Scope) contains(pos int) bool {
	return pos >= s.start_pos && pos <= s.end_pos
}

pub fn (sc Scope) show(depth int, max_depth int) string {
	mut out := ''
	mut indent := ''
	for _ in 0 .. depth * 4 {
		indent += ' '
	}
	out += '$indent# $sc.start_pos - $sc.end_pos\n'
	for _, obj in sc.objects {
		match obj {
			ConstField { out += '$indent  * const: $obj.name - $obj.typ\n' }
			Var { out += '$indent  * var: $obj.name - $obj.typ\n' }
			else {}
		}
	}
	for _, field in sc.struct_fields {
		out += '$indent  * struct_field: $field.struct_type $field.name - $field.typ\n'
	}
	if max_depth == 0 || depth < max_depth - 1 {
		for i, _ in sc.children {
			out += sc.children[i].show(depth + 1, max_depth)
		}
	}
	return out
}

pub fn (sc Scope) str() string {
	return sc.show(0, 0)
}
