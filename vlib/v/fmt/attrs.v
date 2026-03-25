// Copyright (c) 2019-2024 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module fmt

import v.ast

pub fn (mut f Fmt) attrs(attrs []ast.Attr) {
	if attrs.any(it.is_call) {
		mut i := 0
		for i < attrs.len {
			mut j := i + 1
			for j < attrs.len && attrs[j].group_id == attrs[i].group_id {
				j++
			}
			f.attr_group(attrs[i..j])
			i = j
		}
		return
	}
	f.attrs_without_call(attrs)
}

fn (mut f Fmt) attrs_without_call(attrs []ast.Attr) {
	mut sorted_attrs := attrs.clone()
	// Sort the attributes. The ones with arguments come first
	sorted_attrs.sort_with_compare(fn (a &ast.Attr, b &ast.Attr) int {
		d := b.arg.len - a.arg.len
		return if d != 0 { d } else { compare_strings(b.arg, a.arg) }
	})
	for i, attr in sorted_attrs {
		if attr.arg.len == 0 {
			f.single_line_attrs(sorted_attrs[i..])
			break
		}
		f.writeln('@[${attr}]')
	}
}

fn (f &Fmt) attr_arg_str(arg ast.AttrCallArg) string {
	mut s := ''
	quote := if arg.quote == `"` { '"' } else { "'" }
	if arg.has_name {
		s += '${arg.name}: '
	}
	s += match arg.kind {
		.plain, .number, .bool { arg.arg }
		.string { '${quote}${arg.arg}${quote}' }
		.comptime_define { 'if ${arg.arg}' }
	}
	return s
}

fn (f &Fmt) attr_body(attr ast.Attr) string {
	if !attr.is_call {
		return '${attr}'
	}
	mut args := []string{cap: attr.call_args.len}
	for arg in attr.call_args {
		args << f.attr_arg_str(arg)
	}
	return '${attr.name}(${args.join(', ')})'
}

fn visible_attrs_in_group(attrs []ast.Attr) int {
	mut count := 0
	for attr in attrs {
		if !attr.is_call_arg {
			count++
		}
	}
	return count
}

fn (mut f Fmt) attr_group(attrs []ast.Attr) {
	if attrs.len == 0 {
		return
	}
	if !attrs.any(it.is_call) {
		f.attrs_without_call(attrs)
		return
	}
	if visible_attrs_in_group(attrs) == 1 && attrs[0].is_call
		&& attrs[0].pos.last_line > attrs[0].pos.line_nr {
		f.writeln('@[')
		f.indent++
		f.writeln('${attrs[0].name}(')
		f.indent++
		for i, arg in attrs[0].call_args {
			mut suffix := ','
			if i == attrs[0].call_args.len - 1 {
				suffix = ''
			}
			f.writeln('${f.attr_arg_str(arg)}${suffix}')
		}
		f.indent--
		f.writeln(')')
		f.indent--
		f.writeln(']')
		return
	}
	f.single_line_attrs(attrs)
}

@[params]
pub struct AttrsOptions {
pub:
	same_line bool
}

pub fn (mut f Fmt) single_line_attrs(attrs []ast.Attr, options AttrsOptions) {
	if attrs.len == 0 {
		return
	}
	if attrs.any(it.is_call) {
		if options.same_line {
			f.write(' ')
		}
		f.write('@[')
		mut is_first := true
		for attr in attrs {
			if attr.is_call_arg {
				continue
			}
			if !is_first {
				f.write('; ')
			}
			is_first = false
			f.write(f.attr_body(attr))
		}
		f.write(']')
		if !options.same_line {
			f.writeln('')
		}
		return
	}
	f.single_line_attrs_without_call(attrs, options)
}

fn (mut f Fmt) single_line_attrs_without_call(attrs []ast.Attr, options AttrsOptions) {
	mut sorted_attrs := attrs.clone()
	sorted_attrs.sort(a.name < b.name)
	if options.same_line {
		f.write(' ')
	}
	f.write('@[')
	for i, attr in sorted_attrs {
		if i > 0 {
			f.write('; ')
		}
		f.write('${attr}')
	}
	f.write(']')
	if !options.same_line {
		f.writeln('')
	}
}

fn inline_attrs_len(attrs []ast.Attr) int {
	if attrs.len == 0 {
		return 0
	}
	if attrs.any(it.is_call) {
		mut n := 2 // ' ['.len
		mut is_first := true
		mut tmpf := Fmt{}
		for attr in attrs {
			if attr.is_call_arg {
				continue
			}
			if !is_first {
				n += 2 // '; '.len
			}
			is_first = false
			n += tmpf.attr_body(attr).len
		}
		n++ // ']'.len
		return n
	}
	mut n := 2 // ' ['.len
	for i, attr in attrs {
		if i > 0 {
			n += 2 // '; '.len
		}
		n += '${attr}'.len
	}
	n++ // ']'.len
	return n
}
