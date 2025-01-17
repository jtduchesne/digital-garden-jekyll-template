# frozen_string_literal: true
Jekyll::Hooks.register :site, :post_read do |site|
  graph_nodes = []
  graph_edges = []

  all_notes = site.collections['notes'].docs
  all_pages = site.pages

  all_docs = all_notes + all_pages

  link_extension = !!site.config["use_html_extension"] ? '.html' : ''

  # Convert all Wiki/Roam-style double-bracket link syntax to plain HTML
  # anchor tag elements (<a>) with "internal-link" CSS class
  all_docs.each do |current_note|
    all_docs.each do |note_potentially_linked_to|
      new_href = "#{site.baseurl}#{note_potentially_linked_to.url}#{link_extension}"
      anchor_tag = "<a class='internal-link' href='#{new_href}'>\\1</a>"

      # Replace double-bracketed links with label using note title
      # [[A note about cats|this is a link to the note about cats]]
      current_note.content.gsub!(
        /\[\[#{note_potentially_linked_to.data['title']}\|(.+?)(?=\])\]\]/i,
        anchor_tag
      )

      # Replace double-bracketed links using note title
      # [[a note about cats]]
      current_note.content.gsub!(
        /\[\[(#{note_potentially_linked_to.data['title']})\]\]/i,
        anchor_tag
      )

      # Replace double-bracketed links with label using note slug
      # [[cats|this is a link to the note about cats]]
      current_note.content.gsub!(
        /\[\[#{note_potentially_linked_to.data['slug']}\|(.+?)(?=\])\]\]/i,
        anchor_tag
      )

      # Replace double-bracketed links using note slug
      # [[cats]]
      current_note.content.gsub!(
        /\[\[(#{note_potentially_linked_to.data['slug']})\]\]/i,
        anchor_tag
      )
    end

    # At this point, all remaining double-bracket-wrapped words are
    # pointing to non-existing pages, so let's turn them into disabled
    # links by greying them out and changing the cursor

    if site.config["log_broken_links"]
      # Print found broken links when generating site
      current_note.content.match(/\[\[([^|]*?)(?:\|.*?)?\]\]/) do |match|
        Jekyll.logger.warn "\e[0;35mBroken link:\e[0m", "[[#{match[1]}]] in #{current_note.url}"
      end
    end

    current_note.content.gsub!(
      /\[\[(.*)\]\]/,  # match on the remaining double-bracket links
      <<~HTML.chomp    # replace with this HTML (\\1 is what was inside the brackets)
        <span title='BRISÉ.' class='invalid-link'>
          <span class='invalid-link-brackets'>[[</span>
          \\1
          <span class='invalid-link-brackets'>]]</span>
        </span>
      HTML
    )
  end

  # Identify note backlinks and add them to each note
  all_notes.each do |current_note|
    # Nodes: Jekyll
    notes_linking_to_current_note = all_notes.filter do |e|
      e.content.include?(current_note.url)
    end

    # Nodes: Graph
    graph_nodes << {
      id: note_id_from_note(current_note),
      path: "#{site.baseurl}#{current_note.url}#{link_extension}",
      label: current_note.data['title'],
    } unless current_note.path.include?('_notes/index.html')

    # Edges: Jekyll
    current_note.data['backlinks'] = notes_linking_to_current_note

    # Edges: Graph
    notes_linking_to_current_note.each do |n|
      graph_edges << {
        source: note_id_from_note(n),
        target: note_id_from_note(current_note),
      }
    end
  end

  File.write('_includes/notes_graph.json', JSON.dump({
    edges: graph_edges,
    nodes: graph_nodes,
  }))
end

def note_id_from_note(note)
  note.data['title']
    .dup
    .gsub(/\W+/, ' ')
    .delete(' ')
    .to_i(36)
    .to_s
end
