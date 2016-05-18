module MagLev
  def self.unit_of_work(lock: false, lock_expiration: nil, &block)
    ActiveModel::UnitOfWork.create(lock_expiration: lock_expiration, &block)
  end

  module ActiveModel
    # Psuedu transaction support for ActiveModel based classes. Useful for when using a database that does not support
    # real transactions (such as MongoDB). These are basic client-only
    # transactions where all actual save operations are batched and commited at once. This allows you to save multiple
    # objects in sequence without having to first check that they are all valid.
    # Transactions will only fail if any of the records are invalid.
    # You must use save or save! method in order for the save operations to be registered with the
    # transaction. destroy is also supported. Atomic and update methods are not supported due to conflicting
    # with transaction use cases. Instead of using update_attributes, try assign_attributes and then save or save!.
    #
    # This feature also supports Redis mutex locking. When adding a
    module UnitOfWorkable
      extend ActiveSupport::Concern

      included do
        # save is somewhat supported by checking if the record is valid and only adding it to the
        # transaction if it is. Otherwise it just returns false but does not fail the transaction,
        # since it is expected that the false result is to be used to handle things manually
        def save(*args)
          if valid?
            UnitOfWork.add(self) { super }
            true
          else
            false
          end
        end

        def save!(*args)
          UnitOfWork.add(self) { super }
        end

        def destroy
          UnitOfWork.add(self) { super }
        end
      end
    end

    class UnitOfWork
      attr_reader :parent, :locked, :invalid

      def initialize(parent, lock_expiration = nil)
        @lock_expiration = lock_expiration || 10

        # locks are currently tracked at the top most level only
        @locked = parent ? parent.locked : []
        @actions = []
        @after = {commit: [], abort: []}
        @children = []
        @models = Set.new
        if parent
          @parent = parent
          parent.add_child(self)
        end
      end

      def self.create(lock_expiration: nil, &block)
        raise "Transation block required" unless block_given?
        t = UnitOfWork.new(current, lock_expiration)
        MagLev.request_store[:unit_of_work_current] = t
        begin
          block.call(t)
          MagLev.request_store[:unit_of_work_current] = t.parent
          t.commit! unless t.parent or t.aborted? or t.commited?
        rescue
          Rails.logger.warn 'Exception raised, aborting current transaction' if Rails.respond_to? :logger
          MagLev.request_store[:unit_of_work_current] = nil
          raise
        ensure
          t.release_locks
        end
      end

      # adds the model/block to an existing transaction, if there is an existing transaction, otherwise
      # it just calls the block
      def self.add(model, &block)
        transaction = UnitOfWork.current
        if transaction
          transaction.add(model, &block)
        else
          block.call
        end
      end

      def self.lock(model)
        transaction = UnitOfWork.current
        if transaction
          transaction.lock(model)
        else
          false
        end
      end

      def self.lock!(model)
        transaction = UnitOfWork.current
        if transaction
          transaction.lock!(model)
          true
        else
          false
        end
      end

      def self.current
        MagLev.request_store[:unit_of_work_current]
      end
      
      def add_child(child)
        @children << child
      end

      # convenience method that calls save method. validate: false is passed in since
      # validations will have already been checked by the transaction
      def save(model)
        add(model) { model.save(validate: false) }
      end

      def destroy(model)
        add(model, :destroy)
      end

      def add(model = nil, method = nil, &block)
        raise AlreadyCommitedError if commited?

        if method
          raise 'method cannot be provided with block' if block_given?
          block = model.method(method).to_proc
        end

        @models << model if model

        if block
          if @commiting
            block.call
          else
            @actions << block
          end
        end
      end

      def lock(model)
        if @locked.include?(model.id)
          true
        else
          lock = MagLev::Lock.new(model.id.to_s, @lock_expiration)
          if lock.acquire
            @locked << lock
            true
          else
            false
          end
        end
      end

      def lock!(model)
        unless @locked.include?(model.id)
          lock = MagLev::Lock.new(model.id.to_s, @lock_expiration)
          raise LockError.new(model.to_s) unless lock.acquire
          @locked << lock
        end
      end

      # called after transaction is commited
      def after_commit(&block)
        @after[:commit] << block
      end

      # called after transaction is aborted
      def after_abort(&block)
        @after[:abort] << block
      end

      def validate!
        unless @valid or @aborted
          # first go through and find any models that are invalid. Calling the block on them should raise an
          # error
          @models.each do |model|
            if model and model.respond_to?(:invalid?)
              @invalid = model
              raise InvalidError.new(model) if model.invalid?
            end
          end
          @valid = true
        end
      end

      def commited?
        @commited
      end

      def commit!
        return false if commited? or @commiting or @aborted
        begin
          @commiting = true

          @children.each(&:validate!)
          validate!

          @children.each(&:commit!)

          # if no blocks were called (no errors raised) then lets loop back through and call the block on everything
          @actions.each do |block|
            block.call
          end

          @commiting = false
          begin
            @after[:commit].each(&:call)
          ensure
            @commited = true
          end
        ensure
          release_locks
        end
      end

      def release_locks
        # only the top most transaction is responsible for releasing locks at this point. That means
        # that a inner transaction may lock something for longer than it would expect it to be.
        # This can be handled better but for now we are not going to bother to support it unless it becomes an issue.
        @locked.each(&:release) if !@parent
        @locked.clear
      end

      def abort!
        raise "Cannot abort an already commited transaction" if commited?
        begin
          @after[:abort].each(&:call)
        ensure
          @aborted = true
        end
      end

      def aborted?
        !!@aborted
      end

      # raised when unable to acquire a lock on a resource
      class InvalidError < RuntimeError
        attr_reader :model
        def initialize(model)
          super(model.errors.messages)
          @model = model
        end
      end

      # raised when unable to acquire a lock on a resource
      class LockError < RuntimeError
      end

      # raised when unable to acquire a lock on a resource
      class AlreadyCommitedError < RuntimeError
      end
    end

  end
end
