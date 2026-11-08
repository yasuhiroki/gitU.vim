vim9script

export def ToRepoRelativePath(repo_root: string, file_path: string): string
    var clean_root = substitute(resolve(fnamemodify(repo_root, ':p')), '/\+$', '', '')
    var clean_file = resolve(fnamemodify(file_path, ':p'))
    var prefix = clean_root .. '/'
    if stridx(clean_file, prefix) == 0
        return clean_file[len(prefix) :]
    endif
    return file_path
enddef

export def ParseLinePorcelain(lines: list<string>): dict<any>
    var entries: list<dict<any>> = []
    var blame_lines: list<string> = []
    var file_lines: list<string> = []
    var commit_cache: dict<dict<any>> = {}
    var cur_entry: dict<any> = {}

    for line in lines
        if empty(cur_entry)
            var header_match = matchlist(line, '^\(\x\{40\}\) \(\d\+\) \(\d\+\)')
            if len(header_match) >= 4
                var cur_hash = header_match[1]
                var cached = get(commit_cache, cur_hash, {})
                cur_entry = {
                    hash: cur_hash,
                    short_hash: cur_hash[0 : 6],
                    orig_lnum: str2nr(header_match[2]),
                    final_lnum: str2nr(header_match[3]),
                    author: get(cached, 'author', ''),
                    author_time: get(cached, 'author_time', 0),
                    date: get(cached, 'date', ''),
                    summary: get(cached, 'summary', ''),
                    boundary: get(cached, 'boundary', false),
                    prev_hash: get(cached, 'prev_hash', ''),
                    prev_file: get(cached, 'prev_file', ''),
                    filename: get(cached, 'filename', ''),
                    content: '',
                }
            endif
            continue
        endif

        if line[0] == "\t"
            cur_entry.content = line[1 :]
            commit_cache[cur_entry.hash] = {
                author: cur_entry.author,
                author_time: cur_entry.author_time,
                date: cur_entry.date,
                summary: cur_entry.summary,
                boundary: cur_entry.boundary,
                prev_hash: cur_entry.prev_hash,
                prev_file: cur_entry.prev_file,
                filename: cur_entry.filename,
            }

            var date_str = cur_entry.date != '' ? cur_entry.date : '0000-00-00 00:00'
            var blame_line = printf('%s (%s) <%s> %s', cur_entry.short_hash, date_str, cur_entry.author, cur_entry.summary)
            add(entries, cur_entry)
            add(blame_lines, blame_line)
            add(file_lines, cur_entry.content)
            cur_entry = {}
        elseif stridx(line, 'author ') == 0
            cur_entry.author = line[7 :]
        elseif stridx(line, 'author-time ') == 0
            var timestamp = str2nr(line[12 :])
            cur_entry.author_time = timestamp
            cur_entry.date = strftime('%Y-%m-%d %H:%M', timestamp)
        elseif stridx(line, 'summary ') == 0
            cur_entry.summary = line[8 :]
        elseif line == 'boundary'
            cur_entry.boundary = true
        elseif stridx(line, 'previous ') == 0
            var rest = line[9 :]
            var space_idx = stridx(rest, ' ')
            if space_idx > 0
                cur_entry.prev_hash = rest[0 : space_idx - 1]
                cur_entry.prev_file = rest[space_idx + 1 :]
            endif
        elseif stridx(line, 'filename ') == 0
            cur_entry.filename = line[9 :]
        endif
    endfor

    return {
        entries: entries,
        blame_lines: blame_lines,
        file_lines: file_lines,
    }
enddef
