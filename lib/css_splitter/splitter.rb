module CssSplitter

  class Splitter

    MAX_SELECTORS_DEFAULT = 4095

    # returns the specified split of the passed css_string
    def self.split_string(css_string, split = 1, max_selectors = MAX_SELECTORS_DEFAULT)
      rules = split_string_into_rules(css_string)
      extract_part rules, split, max_selectors
    end

    # splits string into array of rules (also strips comments)
    
    ORIGINAL_REGX = "[^}]*}"
    INNER_AT_RULES_REGX = "(?:[^{}]*{[^}]*})*"
    def self.split_string_into_rules(css_string)
      return strip_comments(css_string).chomp.scan(/[^@{]*@[^{]*{#{INNER_AT_RULES_REGX}[^}]*}|#{ORIGINAL_REGX}/)
    end
    def self.extract_part(rules, part = 1, max_selectors = MAX_SELECTORS_DEFAULT)
      return if rules.first.nil?

      charset_statement, rules[0] = extract_charset(rules.first)
      return if rules.nil?

      output = charset_statement || ""
      current_part = 1
      max = max_selectors
      selectors_count = 0
      rules.each do |rule|
        inner_rule = rule.sub(/@media[^{]*{(#{INNER_AT_RULES_REGX})[^}]*}/, '\1') || rule
        from = selectors_count + 1
        to = (selectors_count += count_selectors_of_rule(inner_rule))
        #         min      max
        #----------AAAAAAAAAA---------- EX: (min: 1, max: 10)
        #------------------@@@@-------- EX: (from: 9, to: 12)
        #                from to
        #------------------BBBBBBBBBB-- EX: (min: 9, max: 18)
        #                new_min new_max
        if to > max #out range
          break if current_part >= part
          current_part += 1
          overlap = max - from + 1
          max += max_selectors - overlap
        end
        #         min      max
        #----------AAAAAAAAAA---------- EX: (min: 1, max: 10)
        #----------@@@@---------------- EX: (from: 1, to: 4)
        #        from to
        if to <= max #in range
          next if current_part < part
          output << rule
        end
      end
      return output
    end
    # count selectors of one individual CSS rule
    def self.count_selectors_of_rule(rule)
      parts = strip_comments(rule).partition(/\{/)
      parts.second.empty? ? 0 : parts.first.scan(/,/).count.to_i + 1
    end



    # count selectors of a CSS stylesheet (not used by SprocketsEngine)
    def self.count_selectors(css_file)
      raise "file could not be found" unless File.exists? css_file

      rules = split_string_into_rules(File.read css_file)
      return if rules.first.nil?

      rules.sum{ |rule| count_selectors_of_rule(rule) }
    end



    private

      def self.extract_media(rule)
        if rule.sub!(/^\s*(@media[^{]*{)([^{}]*{[^}]*})$/) { $2 }
          $1
        end
      end

      # extracts potential charset declaration from the first rule
      def self.extract_charset(rule)
        if rule.include?('charset')
          rule.partition(/^\@charset[^;]+;/)[1,2]
        else
          [nil, rule]
        end
      end

      def self.strip_comments(s)
        s.gsub(/\/\*.*?\*\//m, "")
      end

      def self.get_rule_bracket_balance ( rule )
        rule.scan( /}/ ).size - rule.scan( /{/ ).size
      end

  end

end
