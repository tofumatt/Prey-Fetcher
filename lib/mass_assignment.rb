# Oleg Andreev <oleganza@gmail.com>
# November 4, 2008
# License: WTFPL (sam.zoy.org/wtfpl/)
#
module MassAssignment
  
  def self.included(mod)
    mod.extend(ClassMethods)
  end
  
  module ClassMethods
    #
    # :except is a list of protected attributes which cannot be assigned massively
    # :only is a list of attributes which can be assigned massively (through #attributes=()).
    # :error - whether to raise a MassAssignment::Error when protected attribute is passed (default is false)
    #              :error may be a custom exception (pass exception object instead of true)
    # Examples:
    #   mass_assignment :except => [:role, :owner_id, ...], :error => true
    #   mass_assignment :only   => [:name, :email ]
    #
    # Default error:
    #   mass_assignment :default_error => true
    #
    def mass_assignment(opts)
      
      if def_err = (opts[:default_error] || opts[:default_exception])
        def_err = Error if def_err == true
        @mass_assignment_default_error = def_err
        return
      end
      
      [:only, :except].each{|k| opts[k] = [ opts[k] ] if opts[k] && !opts[k].is_a?(Array) }
      
      if @mass_assignment_only && opts[:only]
        @mass_assignment_only &= opts[:only]
      else
        @mass_assignment_only = opts[:only]
      end

      err = opts[:error] || opts[:exception]
      err = Error if err == true
      
      @mass_assignment_except = (opts[:except]||[]).inject(@mass_assignment_except || {}) do |h,k| 
        h[k.to_s] = err || @mass_assignment_default_error || 0
        h
      end
      unless opts[:except]
        @mass_assignment_error  = err || @mass_assignment_error || @mass_assignment_default_error
      end
    end
    attr_accessor :mass_assignment_only,   # array
                  :mass_assignment_except, # hash (for faster has_key? lookup)
                  :mass_assignment_error,   # StandardError subclass or false/nil
                  :mass_assignment_default_error   # error to be set by default
  end
  
  class Error < ::StandardError; end
  
  def attributes=(values_hash)
    
    # :only => [...]

    if only = self.class.mass_assignment_only
      values_hash2 = only.inject({}) do |vh, k|
        if values_hash.has_key?(k)
          vh[k]  = values_hash[k] 
        else
          ks = k.to_s
          vh[ks] = values_hash[ks] if values_hash.has_key?(ks)
        end
        vh
      end
      if err = self.class.mass_assignment_error
        raise err if values_hash2.size < values_hash.size
      end
    
    # :except => [...]
    
    elsif (except = self.class.mass_assignment_except) && !except.empty?
      values_hash2 = values_hash.inject(values_hash.dup) do |vh, (k, v)|
        if err = except[ks = k.to_s]
          raise err if err != 0
          vh.delete(k)
        end
        vh
      end
    
    # no filters
    else
      values_hash2 = values_hash
    end
    
    # Now attributes are safe
    super(values_hash2)
  end 
  
end

#
# TESTS
#

if $0 == __FILE__
  
  super_class = Class.new do
    attr_accessor :attributes
    def should_raise(attrs)
      begin
        self.attributes = attrs
        false
      rescue MassAssignment::Error
        true
      end
    end
    def should_not_raise(attrs)
      !should_raise(attrs)
    end
  end
  
  def assert(a)
    print "."
    $tests_count ||= 0
    $tests_count += 1
    a or raise "Assertion failed!"
  end
  
  only_with_exceptions = Class.new(super_class) do 
    include MassAssignment
    mass_assignment :only => [:a, :b], :error => true
  end
  
  obj = only_with_exceptions.new
    
  assert obj.should_not_raise({})
  assert obj.should_not_raise({:a => 1})
  assert obj.should_not_raise({:a => 1, :b => 2})
  assert obj.should_not_raise({"a" => 1})
  assert obj.should_not_raise({"a" => 1, "b" => 2})
  assert obj.should_raise({:a => 1, :b => 2, :c => 3})
  assert obj.should_raise({:a => 1, :b => 2, "c" => 3})


  except_with_exceptions = Class.new(super_class) do 
    include MassAssignment
    mass_assignment :except => [:c, :d], :error => true
  end
  
  obj = except_with_exceptions.new
  
  assert obj.should_not_raise({})
  assert obj.should_not_raise({:a => 1})
  assert obj.should_not_raise({:a => 1, :b => 2})
  assert obj.should_not_raise({"a" => 1})
  assert obj.should_not_raise({"a" => 1, "b" => 2})
  assert obj.should_raise({:a => 1, :b => 2, :c => 3})
  assert obj.should_raise({:a => 1, :b => 2, "c" => 3})


  no_filter = Class.new(super_class) do 
    include MassAssignment
  end

  obj = no_filter.new

  assert obj.should_not_raise({})
  assert obj.should_not_raise({:a => 1})
  assert obj.should_not_raise({:a => 1, :b => 2})
  assert obj.should_not_raise({"a" => 1})
  assert obj.should_not_raise({"a" => 1, "b" => 2})
  assert obj.should_not_raise({:a => 1, :b => 2, :c => 3})
  assert obj.should_not_raise({:a => 1, :b => 2, "c" => 3})
  
  puts
  puts
  puts "#{$tests_count} tests passed."
end
