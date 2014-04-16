class Story < ActiveRecord::Base
  # attribute names
  #["id", "title", "description", "latitude", "longitude", "zoom", "layers", "body", "filename", 
  # "layout", "language", "image_url", "user_id", "group_id", "created_at", "updated_at"]

  belongs_to :user
  belongs_to :group
  
  validates :title, :presence => true
  validates :title, :length => { :in => 5..250 }
  validates :title,  :uniqueness => true
  validates :description, :length => { :maximum => 1000 } 
  validates_numericality_of :latitude, :allow_nil => true, :greater_than_or_equal_to => -90, :less_than_or_equal_to => 90
  validates_numericality_of :longitude, :allow_nil => true, :greater_than_or_equal_to => -180, :less_than_or_equal_to => 180
  validate :validate_layers
  validate :validate_body
  #validate :validate_links
  validate :validate_permalink
 
  serialize :body
  serialize :layers
  
  before_create :make_filename
  after_save    :save_story_file
  after_destroy :delete_files
  before_save :squish_text

  
  def self.default_params
    {
      "layers" => {},
      "body" => {
        "report" => {"title"=>"Report", 
          "sections"=>[{"title" => "", 
              "type" => "", 
              "text" => "", 
              "link" => ""}
          ]
        },
        "sites"   => {"title"=>"Locations",
          "sections"=>[{ "title"=> "",
              "type" => "map-nav",
              "text" => "",
              "links" => [
                {"title" => "",
                  "link" => "",
                  "text" => ""}
              ]
            }]
        },         
        "layers"  => {"title"=>"Layers", 
          "sections"=>[{"title"=> "",
              "type" => "layer-ui",
              "text" => ""
            }                  
          ]}
        
      }
    }
  end
  
  #based on the RESTRICTED sanitize congfiguration, but allowing links and images
  def self.sanitize_config
    sanitize_config = {
      :elements => %w[b em i strong u a img],
      :add_attributes => { 'a' => ['href', 'title'] },
      :protocols => {'a'  => {'href' => ['http', 'https']},
                     'img' => {'src'  => ['http', 'https']}
      }
    }
    
    sanitize_config
  end
  
  def description
    RichText.new("html", read_attribute(:description))
  end
  
  
  #e.g  exploring-story
  def filename_slug
    self.title.parameterize
  end
   
  
  #e.g. moabi.org/exploring-story/en
  def permalink
    story_url = defined?(STORY_URL) ? STORY_URL : ""
    lang = self.language || "en"
    story_url + filename_slug + "/" + lang
  end
  
  
  #e.g 0100-04-04-exploring-story.md
  def make_filename
    time_stamp = Time.current.strftime("%Y-%m-%d")
    self.filename ="#{time_stamp}-#{filename_slug}.html"
  end
  
  
  #e.g. /var/site/_posts/projects/0100-04-04-exploring-story.md
  def story_file_path
    story_dir = defined?(STORY_DIR) ? STORY_DIR : ""
    File.join(story_dir, self.filename)
  end
  
        
  def save_story_file
    logger.debug "render and save story file#{story_file_path}"
    @story = self
    @story.sanitize_text
   
    story_file = File.open(story_file_path,  "w+")
    template = File.open(File.join(Rails.root, "app/views/stories/story.md.erb")).read
    story_file.puts ERB.new(template, nil, "<>-").result( binding )
    story_file.close
  end

  
  def delete_files
    if File.exist?(story_file_path)
      logger.debug "deleting file #{story_file_path}"
      File.delete(story_file_path)
    end    
  end
  
  #removes groups of whitespace and newlines etc
  #sanitizes for html using the config
  def sanitize_text
    self.description = Sanitize.clean(self.description, Story.sanitize_config).html_safe
    Story.default_params["body"].keys.each do | key |
      if self.body[key]["sections"]
        self.body[key]["sections"].each do | section |
         section["text"] = Sanitize.clean(section["text"], Story.sanitize_config).html_safe if section["text"]
        end
      end
    end
  end
  
  def squish_text
    self.description = self.description.squish
    Story.default_params["body"].keys.each do | key |
      if self.body[key]["sections"]
        self.body[key]["sections"].each do | section |
          section["text"] = section["text"].squish if section["text"]
        end
      end
    end

  end

  def validate_layers
    if layers.empty?  || (layers.size == 1 && layers[0].blank?)
      errors.add(:layers, "are empty and have not been chosen")
    end  
  end
  
  def validate_body
    default_keys = Story.default_params["body"].keys.sort
    if body.keys.nil?
      errors.add(:body, "needs to be in the correct format")
    end
    if body.keys.sort != default_keys
      errors.add(:body, "should have #{default_keys}")
    end
  end
  
  #link is in osm permalink format:
  #map=8/-4.39023/17.13867&layers=B,R,E,I,L,M,O,P,T
  def validate_links
    links =  body["report"]["sections"].collect{|s| s["link"]} +  body["sites"]["sections"][0]["links"].collect{|s| s["link"]}
    links = links.compact
    
    links.each do | link |
      unless link.include?("map=") || link.include?("layers=")
        errors.add(:body, "should have correctly formatted links")
        break
      end
    end
  end
  
  def validate_permalink
    if self.new_record?
      titles = Story.select("title").collect{|t| t.title.parameterize}
    else
      titles = Story.select("title").where(["id != ?", self.id]).collect{|t| t.title.parameterize}
    end
    
    if titles.include?(self.filename_slug)
      errors.add(:title, "should be unique")
    end
  end
  
  
  
end
