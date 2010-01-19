require File.join(File.dirname(__FILE__), 'test_helper')

class HasMachineTags::FinderTest < Test::Unit::TestCase
  before(:each) { 
    [Tag, Tagging, TaggableModel].each {|e| e.delete_all}
  }
  
  def create_extra_taggable
    TaggableModel.create(:tag_list=>"blah:blih=bluh")
  end
  
  def create(name, tag_list)
    TaggableModel.create(:tag_list=>tag_list)
  end
  
  def add_minerals
    @ruby = create(:ruby,           "testing:color=red, testing:opacity=low, 
                                     testing:precious=yes, testing:lustre=5, 
                                     properties:hardness=5")
                                     
    @garnet = create(:garnet,       "testing:color=red, testing:opacity=low, 
                                     testing:precious=no")
                                     
    @sapphire = create(:sapphire,   "testing:color=blue, testing:opacity=low, 
                                      testing:lustre=6")
                                      
    @brick = create(:brick,         "testing:color=red, testing:opacity=high, 
                                     properties:hardness=2")
    
  end
  
  context "TaggableModel" do
    context "finds by" do
      before(:each) { 
        @taggable = TaggableModel.create(:tag_list=>"url:lang=ruby")
        create_extra_taggable
      }
    
      test "namespace wildcard machine tag" do
        TaggableModel.tagged_with("url:").should == [@taggable]
        TaggableModel.tagged_with("orl:").should == []
      end
    
      test "predicate wildcard machine tag" do
        TaggableModel.tagged_with("lang=").should == [@taggable]
        TaggableModel.tagged_with("long=").should == []
      end
    
      test "value wildcard machine tag" do
        TaggableModel.tagged_with("=ruby").should == [@taggable]
        TaggableModel.tagged_with("=rabies").should == []
      end
    
      test "namespace-value wildcard machine tag" do
        TaggableModel.tagged_with("url.ruby").should == [@taggable]
        TaggableModel.tagged_with("url.robot").should == []
        TaggableModel.tagged_with("earl.ruby").should == []
      end
      
      test "predicate-value wildcard machine tag" do
        TaggableModel.tagged_with("lang=ruby").should == [@taggable]
        TaggableModel.tagged_with("lamp=ruby").should == []
        TaggableModel.tagged_with("lang=rusty").should == []
      end
    end
    
    context "finds with" do
      test "multiple machine tags as an array" do
        @taggable = TaggableModel.create(:tag_list=>"article:todo=later")
        @taggable2 = TaggableModel.create(:tag_list=>"article:tags=funny")
        create_extra_taggable
        results = TaggableModel.tagged_with(["article:todo=later", "article:tags=funny"])
        results.size.should == 2
        results.include?(@taggable).should be(true)
        results.include?(@taggable2).should be(true)
      end
      
      test "multiple machine tags as a delimited string" do
        @taggable = TaggableModel.create(:tag_list=>"article:todo=later")
        @taggable2 = TaggableModel.create(:tag_list=>"article:tags=funny")
        create_extra_taggable
        results = TaggableModel.tagged_with("article:todo=later, article:tags=funny")
        results.size.should == 2
        results.include?(@taggable).should be(true)
        results.include?(@taggable2).should be(true)
      end
      
      test "condition option" do
        @taggable = TaggableModel.create(:title=>"so limiting", :tag_list=>"url:tags=funny" )
        create_extra_taggable
        TaggableModel.tagged_with("url:tags=funny", :conditions=>"title = 'so limiting'").should == [@taggable]
      end
      
      test "multiple matchings per row" do
        @ruby = TaggableModel.create(:tag_list=>"red, clear, precious")
        @sapphire = TaggableModel.create(:tag_list=>"blue, clear")
        results = TaggableModel.tagged_with(["red", "clear", "precious", "blue"])
        # note that until you inspect/invoke/etc the scope it will have a size 
        # of 5, trying to select distinct doesn't help because the select(count)
        # used for evaluating <scope>.size takes precedence...
        # :select => "DISTINCT(id)" and using .length works
        results.to_a.size.should == 2
        
      end
      
      test "exclude option (normal tags)" do
        @ruby = TaggableModel.create(:tag_list=>"red, clear, precious")
        @garnet = TaggableModel.create(:tag_list=>"red, clear")
        @sapphire = TaggableModel.create(:tag_list=>"blue, clear")
        @brick = TaggableModel.create(:tag_list=>"red, solid")
        
        results = TaggableModel.tagged_with(["red"], :exclude => true)
        results.to_a.size.should == 1
        results.include?(@sapphire).should be(true)
        
        results = TaggableModel.tagged_with(["red", "clear"], :exclude => true)
        results.to_a.size.should == 0
        
        results = TaggableModel.tagged_with(["solid"], :exclude => true)
        results.to_a.size.should == 3
        results.include?(@ruby).should be(true)
        results.include?(@sapphire).should be(true)
        results.include?(@garnet).should be(true)
      end
      
      test "exclude option (machine tags)" do
        add_minerals
        
        results = TaggableModel.tagged_with(["testing:color=red", "testing:opacity=high"], :exclude => true)
        results.to_a.size.should == 1
        results.include?(@sapphire).should be(true)
        
        results = TaggableModel.tagged_with(["testing:color=blue", "testing:opacity=high"], :exclude => true)
        results.to_a.size.should == 2
        results.include?(@ruby).should be(true)
        results.include?(@garnet).should be(true)
        
        results = TaggableModel.tagged_with(["testing:precious=no", "testing:lustre=6", "properties:hardness=2"], :exclude => true)
        results.to_a.size.should == 1
        results.include?(@ruby).should be(true)
        
        results = TaggableModel.tagged_with(["testing:color=red", "testing:color=blue"], :exclude => true)
        results.to_a.size.should == 0
      end
      
      test "exclude option (machine tags, wildcards)" do
        add_minerals
        
        results = TaggableModel.tagged_with(["color="], :exclude => true)
        results.to_a.size.should == 0
        
        results = TaggableModel.tagged_with(["precious=", "lustre="], :exclude => true)
        results.to_a.size.should == 1
        results.include?(@brick).should be(true)
        
        results = TaggableModel.tagged_with(["=no", "=2", "properties:hardness=2"], :exclude => true)
        results.to_a.size.should == 2
        results.include?(@ruby).should be(true)
        results.include?(@sapphire).should be(true)
        
        results = TaggableModel.tagged_with(["properties:", "lustre=", "=low"], :exclude => true)
        results.to_a.size.should == 0
        
        results = TaggableModel.tagged_with(["properties:", "lustre="], :exclude => true)
        results.to_a.size.should == 1
        results.include?(@garnet).should be(true)
        
      end
      
      test "match_all option (normal tags)" do
        @ruby = TaggableModel.create(:tag_list=>"red, clear, precious")
        @garnet = TaggableModel.create(:tag_list=>"red, clear")
        @sapphire = TaggableModel.create(:tag_list=>"blue, clear")
        @brick = TaggableModel.create(:tag_list=>"red, solid")
        
        results = TaggableModel.tagged_with(["red", "solid"], :match_all => true)
        results.to_a.size.should == 1
        results.include?(@brick).should be(true)
        
        results = TaggableModel.tagged_with(["red", "clear"], :match_all => true)
        results.to_a.size.should == 2
        results.include?(@ruby).should be(true)
        results.include?(@garnet).should be(true)
      end
      
      test "match_all option (machine tags)" do
        add_minerals
        
        results = TaggableModel.tagged_with(["testing:color=red", "testing:opacity=high"], :match_all => true)
        results.to_a.size.should == 1
        results.include?(@brick).should be(true)
        
        results = TaggableModel.tagged_with(["testing:color=red", "testing:opacity=low"], :match_all => true)
        results.to_a.size.should == 2
        results.include?(@ruby).should be(true)
        results.include?(@garnet).should be(true)
      end
    
#      THIS IS CURRENTLY UNSUPPORTED. Only use match_all without wildcards in tags.
#      
#      test "match_all option (machine tags, wildcards)" do
#        add_minerals
#        
#        results = TaggableModel.tagged_with(["properties:hardness", "=no"], :match_all => true)
#        results.to_a.size.should == 0
#        
#        results = TaggableModel.tagged_with(["hardness=", "=yes"], :match_all => true)
#        results.to_a.size.should == 1
#        results.include?(@ruby).should be(true)
#        
#        results = TaggableModel.tagged_with(["hardness=", "=5"], :match_all => true)
#        results.to_a.size.should == 1
#        results.include?(@ruby).should be(true)
#        
#        results = TaggableModel.tagged_with(["testing:lustre", "testing:color=blue"], :match_all => true)
#        results.to_a.size.should == 1
#        results.include?(@sapphire).should be(true)
#
#        results = TaggableModel.tagged_with(["color=", "properties:hardness=2"], :match_all => true)
#        results.to_a.size.should == 1
#        results.include?(@brick).should be(true)
#      end
      
    end

    context "when queried with normal tag" do
      before(:each) { @taggable = TaggableModel.new }
      test "doesn't find if machine tagged" do
        @taggable.tag_list = 'url:tags=square'
        @taggable.save
        Tag.count.should == 1
        TaggableModel.tagged_with("square").should == []
      end
    
      test "finds if tagged normally" do
        @taggable.tag_list = 'square, some:machine=tag'
        @taggable.save
        TaggableModel.tagged_with("square").should == [@taggable]
      end
    end        
  end  
end