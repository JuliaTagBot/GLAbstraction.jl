using GeometryTypes: Face

mutable struct VertexArray{Vertex, Face, IT}
    id::GLuint
    length::Int
    buffer::Vector
    indices::IT
    context::Context
    function (::Type{VertexArray{Vertex, Face}}){Vertex, Face, IT}(id, bufferlength, buffers, indices::IT)
        new{Vertex, Face, IT}(id, bufferlength, buffers, indices, current_context())
    end
end
function VertexArray{T}(buffer::Buffer{T}, indices, attrib_location)
    id = glGenVertexArrays()
    glBindVertexArray(id)
    face_type = if isa(indices, Buffer)
        bind(indices)
        eltype(indices)
    elseif isa(indices, DataType) && indices <: Face
        indices
    elseif isa(indices, Integer)
        Face{1, OffsetInteger{1, GLint}}
    else
        error("indices must be Int, Buffer or Face type")
    end
    bind(buffer)
    if !is_glsl_primitive(T)
        for i = 1:nfields(T)
            FT = fieldtype(T, i); ET = eltype(FT)
            glVertexAttribPointer(
                attrib_location,
                cardinality(FT), julia2glenum(ET),
                GL_FALSE, sizeof(T), Ptr{Void}(fieldoffset(T, i))
            )
            glEnableVertexAttribArray(attrib_location)
            attrib_location += 1
        end
    else
        FT = T; ET = eltype(FT)
        glVertexAttribPointer(
            attrib_location,
            cardinality(FT), julia2glenum(ET),
            GL_FALSE, 0, C_NULL
        )
        glEnableVertexAttribArray(attrib_location)
    end
    glBindVertexArray(0)
    obj = VertexArray{T, face_type}(id, length(buffer), [buffer], indices)
    obj
end
function VertexArray{T}(buffer::AbstractArray{T}, attrib_location = 0; face_type = gl_face_type(T))
    VertexArray(Buffer(buffer), face_type, attrib_location)
end
function VertexArray{T, AT <: AbstractArray, IT <: AbstractArray}(
        view::SubArray{T, 1, AT, Tuple{IT}, false}, attrib_location = 0; face_type = nothing # TODO figure out better ways then ignoring face type
    )
    indexes = view.indexes[1]
    buffer = view.parent
    VertexArray(Buffer(buffer), indexbuffer(indexes), attrib_location)
end

# TODO
Base.convert(::Type{VertexArray}, x) = VertexArray(x)
Base.convert(::Type{VertexArray}, x::VertexArray) = x

gl_face_enum{V, IT, T <: Integer}(::VertexArray{V, T, IT}) = GL_POINTS
gl_face_enum{V, IT, I}(::VertexArray{V, Face{1, I}, IT}) = GL_POINTS
gl_face_enum{V, IT, I}(::VertexArray{V, Face{2, I}, IT}) = GL_LINES
gl_face_enum{V, IT, I}(::VertexArray{V, Face{3, I}, IT}) = GL_TRIANGLES

# gl_face_type(::Type{<: NTuple{2, <: AbstractVertex}}) = Face{2, Int}
gl_face_type(::Type) = Face{1, Int} # Default to Point
gl_face_type(::Type{T}) where T <: Face = T

is_struct{T}(::Type{T}) = !(sizeof(T) != 0 && nfields(T) == 0)
is_glsl_primitive{T <: StaticVector}(::Type{T}) = true
is_glsl_primitive{T <: Union{Float32, Int32}}(::Type{T}) = true
is_glsl_primitive(T) = false

_typeof{T}(::Type{T}) = Type{T}
_typeof{T}(::T) = T
function free(x::VertexArray)
    if !is_current_context(x.context)
        return # don't free from other context
    end
    id = [x.id]
    try
        glDeleteVertexArrays(1, id)
    catch e
        free_handle_error(e)
    end
    return
end
function draw{V, T, IT <: Buffer}(vbo::VertexArray{V, T, IT})
    glDrawElements(
        gl_face_enum(vbo),
        length(vbo.indices) * GLAbstraction.cardinality(vbo.indices),
        GLAbstraction.julia2glenum(eltype(IT)), C_NULL
    )
end
function draw{V, T}(vbo::VertexArray{V, T, DataType})
    glDrawArrays(gl_face_enum(vbo), 0, length(vbo))
end